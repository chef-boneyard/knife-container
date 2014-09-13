#
# Copyright:: Copyright (c) 2014 Chef Software Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'spec_helper'
require 'chef/knife/container_docker_build'
Chef::Knife::ContainerDockerBuild.load_deps

describe Chef::Knife::ContainerDockerBuild do

  let(:stdout_io) { StringIO.new }
  let(:stderr_io) { StringIO.new }
  let(:argv) { %w[ docker/demo ] }

  def stdout
    stdout_io.string
  end

  before do
    allow(KnifeContainer::Plugins::Docker).to receive(:validate!)
    allow(KnifeContainer::Plugins::Berkshelf).to receive(:validate!)
  end

  let(:default_dockerfiles_path) do
    File.expand_path("dockerfiles", fixtures_path)
  end

  subject(:knife) do
    Chef::Knife::ContainerDockerBuild.new(argv).tap do |c|
      allow(c).to receive(:output).and_return(true)
      c.parse_options(argv)
      c.merge_configs
    end
  end

  describe '#run' do
    before(:each) do
      allow(knife).to receive(:validate)
      allow(knife).to receive(:run_berks)
      allow(knife).to receive(:build_docker_image)
      allow(knife).to receive(:cleanup_artifacts)
      Chef::Config.reset
      Chef::Config[:chef_repo_path] = tempdir
      allow(File).to receive(:exist?).with(File.join(tempdir, 'dockerfiles', 'docker', 'demo', 'chef', 'zero.rb')).and_return(true)
    end

    context 'by default' do
      let(:argv) { %w[ docker/demo ] }

      it 'parses argv, run berkshelf, build the image and cleanup the artifacts' do
        expect(knife).to receive(:validate)
        expect(knife).to receive(:setup_config_defaults)
        expect(knife).to receive(:run_berks)
        expect(knife).to receive(:build_docker_image)
        expect(knife).to receive(:cleanup_artifacts)
        knife.run
      end
    end

    context '--no-berks is passed' do
      let(:argv) { %w[ docker/demo --no-berks ] }

      it 'does not run berkshelf' do
        expect(knife).not_to receive(:run_berks)
        knife.run
      end
    end

    context '--no-cleanup is passed' do
      let(:argv) { %w[ docker/demo --no-cleanup ] }

      it 'does not clean up the artifacts' do
        expect(knife).not_to receive(:cleanup_artifacts)
        knife.run
      end
    end

    context 'when --secure-dir is passed' do
      let(:argv) { %w[ docker/demo --secure-dir /path/to/dir ] }

      before do
        allow(File).to receive(:directory?).with('/path/to/dir').and_return(true)
        allow(File).to receive(:exist?).with('/path/to/dir/validation.pem').and_return(true)
        allow(File).to receive(:exist?).with('/path/to/dir/client.pem').and_return(false)
      end

      it 'uses contents of specified directory for secure credentials during build' do
        expect(knife).to receive(:backup_secure)
        expect(knife).to receive(:restore_secure)
        knife.run
      end
    end
  end

  describe '#validate' do
    let(:argv) { %w( docker/demo ) }

    it 'sets up/verifies Docker and Berkshelf and verifies the necessary Chef configuration file exists' do
      expect(knife).to receive(:setup_and_verify_docker)
      expect(knife).to receive(:verify_config_file)
      expect(knife).to receive(:setup_and_verify_berkshelf)
      knife.validate
    end

    context 'when argv is empty' do
      let(:argv) { %W[] }

      it 'raises ValidationError' do
        expect { knife.validate }.to raise_error(KnifeContainer::Exceptions::ValidationError)
      end
    end

    context 'when secure_dir is true' do
      let(:argv) { %w[ docker/demo --secure-dir /path/to/dir ] }

      it 'verifies secure directory that stores credentials' do
        expect(knife).to receive(:setup_and_verify_docker)
        expect(knife).to receive(:verify_config_file)
        expect(knife).to receive(:setup_and_verify_berkshelf)
        expect(knife).to receive(:verify_secure_directory)
        knife.validate
      end
    end
  end

  describe '#setup_config_defaults' do
    before do
      Chef::Config.reset
      Chef::Config[:chef_repo_path] = tempdir
      allow(File).to receive(:exist?).with(File.join(tempdir, 'dockerfiles', 'docker', 'demo', 'chef', 'zero.rb')).and_return(true)
    end

    let(:argv) { %w[ docker/demo ]}

    context 'Chef::Config[:dockerfiles_path] has not been set' do
      it 'sets dockerfiles_path to Chef::Config[:chef_repo_path]/dockerfiles' do
        allow($stdout).to receive(:write)
        knife.setup_config_defaults
        expect(knife.config[:dockerfiles_path]).to eql("#{Chef::Config[:chef_repo_path]}/dockerfiles")
      end
    end
  end

  describe '#run_berks' do
    let(:argv) { %W[ docker/demo ] }

    before(:each) do
      Chef::Config.reset
      Chef::Config[:chef_repo_path] = tempdir
      Chef::Config[:knife][:dockerfiles_path] = default_dockerfiles_path
    end

    let(:docker_context) { File.join(Chef::Config[:knife][:dockerfiles_path], 'docker', 'demo') }

    context 'when docker image was init in local mode' do
      before do
        allow(File).to receive(:exist?).with(File.join(docker_context, 'chef', 'zero.rb')).and_return(true)
        allow(File).to receive(:exist?).with(File.join(docker_context, 'chef', 'client.rb')).and_return(false)
        allow(knife).to receive(:chef_repo).and_return(File.join(docker_context, "chef"))
      end

      it 'run Berkshelf.vendor' do
        expect(KnifeContainer::Plugins::Berkshelf).to receive(:vendor)
        knife.run_berks
      end
    end

    context 'when docker image was init in client mode' do
      before do
        allow(File).to receive(:exist?).with(File.join(docker_context, 'chef', 'zero.rb')).and_return(false)
        allow(File).to receive(:exist?).with(File.join(docker_context, 'chef', 'client.rb')).and_return(true)
        allow(knife).to receive(:chef_repo).and_return(File.join(docker_context, "chef"))
      end

      it 'calls run_berks_upload' do
        expect(KnifeContainer::Plugins::Berkshelf).to receive(:upload)
        knife.run_berks
      end
    end
  end

  describe '#cleanup_artifacts' do
    let(:argv) { %w[ docker/demo ] }
    before { allow(knife).to receive(:node_name).and_return('docker-demo-build') }

    context 'running in server-mode' do
      it 'should delete the node and client objects from the Chef Server' do
        expect(knife).to receive(:destroy_item).with(Chef::Node, 'docker-demo-build', 'node')
        expect(knife).to receive(:destroy_item).with(Chef::ApiClient, 'docker-demo-build', 'client')
        knife.cleanup_artifacts
      end
    end
  end
end
