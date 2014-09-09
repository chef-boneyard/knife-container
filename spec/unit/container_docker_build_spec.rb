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
      allow(knife).to receive(:run_berks)
      allow(knife).to receive(:build_docker_image)
      allow(knife).to receive(:cleanup_artifacts)
      allow(knife).to receive(:berks_installed?).and_return(true)
      Chef::Config.reset
      Chef::Config[:chef_repo_path] = tempdir
      allow(File).to receive(:exist?).with(File.join(tempdir, 'dockerfiles', 'docker', 'demo', 'chef', 'zero.rb')).and_return(true)
    end

    context 'by default' do
      let(:argv) { %w[ docker/demo ] }

      it 'parses argv, run berkshelf, build the image and cleanup the artifacts' do
        expect(knife).to receive(:validate).and_call_original
        expect(knife).to receive(:setup_config_defaults).and_call_original
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
    let(:argv) { %W[] }

    before { allow(knife).to receive(:berks_installed?).and_return(true) }

    context 'when argv is empty' do
      it 'prints usage and exits' do
        expect(knife).to receive(:show_usage)
        expect(knife.ui).to receive(:fatal)
        expect { knife.run }.to raise_error(SystemExit)
      end
    end

    context 'when Berkshelf is not installed' do
      let(:argv) { %w[ docker/demo ] }

      before { allow(knife).to receive(:berks_installed?).and_return(false) }

      it 'does not run berks' do
        expect(knife.ui).to receive(:warn)
        knife.validate
        expect(knife.config[:run_berks]).to eql(false)
      end
    end

    context 'when --no-cleanup was passed' do
      let(:argv) { %w[ docker/demo --no-cleanup ] }

      it 'sets config[:cleanup] to false' do
        knife.validate
        expect(knife.config[:cleanup]).to eql(false)
      end
    end

    context 'when --no-berks was not passed' do
      let(:argv) { %w[ docker/demo ] }

      context 'and Berkshelf is not installed' do
        let(:berks_output) { double("berks -v output", stdout: "berks not found") }

        before do
          allow(knife).to receive(:berks_installed?).and_return(false)
        end

        it 'sets run_berks to false' do
          knife.validate
          expect(knife.config[:run_berks]).to eql(false)
        end
      end
    end

    context 'when --berks-config was passed' do
      let(:argv) { %w[ docker/demo --berks-config my_berkshelf/config.json ] }

      context 'and configuration file does not exist' do
        before do
          allow(File).to receive(:exist?).with('my_berkshelf/config.json').and_return(false)
        end

        it 'exits immediately' do
          expect(knife.ui).to receive(:fatal)
          expect { knife.validate }.to raise_error(SystemExit)
        end
      end
    end

    context 'when --secure-dir is passed' do
      let(:argv) { %w[ docker/demo --secure-dir /path/to/dir ] }

      context 'and directory does not exist' do
        before { allow(File).to receive(:directory?).with('/path/to/dir').and_return(false) }

        it 'throws an error' do
          expect(knife.ui).to receive(:fatal)
          expect { knife.validate }.to raise_error(SystemExit)
        end
      end

      context 'and validation or client key does not exist' do
        before do
          allow(File).to receive(:directory?).with('/path/to/dir').and_return(false)
          allow(File).to receive(:exist?).with('/path/to/dir/validation.pem').and_return(false)
          allow(File).to receive(:exist?).with('/path/to/dir/client.pem').and_return(false)
        end

        it 'throws an error' do
          expect(knife.ui).to receive(:fatal)
          expect { knife.validate }.to raise_error(SystemExit)
        end
      end
    end

    context 'when an invalid dockerfile name is given' do
      let(:argv) { %w[ http://reg.example.com/demo ] }

      it 'throws an error' do
        expect(knife).to receive(:valid_dockerfile_name?).and_return(false)
        expect(knife.ui).to receive(:fatal)
        expect{ knife.validate }.to raise_error(SystemExit)
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

  describe "#run_berks" do
    let(:argv) { %W[ docker/demo ] }

    before(:each) do
     Chef::Config.reset
     Chef::Config[:chef_repo_path] = tempdir
     Chef::Config[:knife][:dockerfiles_path] = default_dockerfiles_path
    end

    let(:docker_context) { File.join(Chef::Config[:knife][:dockerfiles_path], 'docker', 'demo') }

    context 'when there is no Berksfile' do
      before { allow(File).to receive(:exist?).with(File.join(docker_context, 'Berksfile')).and_return(false) }

      it 'returns doing nothing' do
        expect(knife).not_to receive(:run_berks_vendor)
        expect(knife).not_to receive(:run_berks_upload)
        knife.run_berks
      end
    end

    context 'when docker image was init in local mode' do
      before do
        allow(File).to receive(:exist?).with(File.join(docker_context, 'Berksfile')).and_return(true)
        allow(File).to receive(:exist?).with(File.join(docker_context, 'chef', 'zero.rb')).and_return(true)
        allow(File).to receive(:exist?).with(File.join(docker_context, 'chef', 'client.rb')).and_return(false)
        allow(knife).to receive(:chef_repo).and_return(File.join(docker_context, "chef"))
      end

      it 'calls run_berks_vendor' do
        expect(knife).to receive(:run_berks_vendor)
        knife.run_berks
      end
    end

    context 'when docker image was init in client mode' do
      before do
        allow(File).to receive(:exist?).with(File.join(docker_context, 'Berksfile')).and_return(true)
        allow(File).to receive(:exist?).with(File.join(docker_context, 'chef', 'zero.rb')).and_return(false)
        allow(File).to receive(:exist?).with(File.join(docker_context, 'chef', 'client.rb')).and_return(true)
        allow(knife).to receive(:chef_repo).and_return(File.join(docker_context, "chef"))
      end

      it 'calls run_berks_upload' do
        expect(knife).to receive(:run_berks_upload)
        knife.run_berks
      end
    end
  end

  describe '#run_berks_install' do
    it 'calls `berks install`' do
      expect(knife).to receive(:run_command).with('berks install')
      knife.run_berks_install
    end
  end

  describe '#run_berks_vendor' do

    before(:each) do
     Chef::Config.reset
     Chef::Config[:chef_repo_path] = tempdir
     Chef::Config[:knife][:dockerfiles_path] = default_dockerfiles_path
     allow(knife).to receive(:docker_context).and_return(File.join(default_dockerfiles_path, 'docker', 'demo'))
     allow(knife).to receive(:run_berks_install)
    end

    let(:docker_context) { File.join(Chef::Config[:knife][:dockerfiles_path], 'docker', 'demo') }

    context "cookbooks directory already exists in docker context" do
      before do
        allow(File).to receive(:exist?).with(File.join(docker_context, 'chef', 'cookbooks')).and_return(true)
      end

      context 'and force-build was specified' do
        let(:argv) { %w[ docker/demo --force ]}

        it "deletes the existing cookbooks directory and runs berks.vendor" do
          expect(FileUtils).to receive(:rm_rf).with(File.join(docker_context, 'chef', 'cookbooks'))
          expect(knife).to receive(:run_berks_install)
          expect(knife).to receive(:run_command).with("berks vendor #{File.join(docker_context, 'chef', 'cookbooks')}")
          knife.run_berks_vendor
        end

      end

      context 'and force-build was not specified' do
        let(:argv) { %w[ docker-demo ] }

        it 'errors out' do
          allow($stdout).to receive(:write)
          allow($stderr).to receive(:write)
          expect { knife.run_berks_vendor }.to raise_error(SystemExit)
        end
      end
    end

    context 'cookbooks directory does not yet exist' do
      before do
        allow(File).to receive(:exist?).with(File.join(docker_context, 'chef', 'cookbooks')).and_return(false)
      end

      it 'calls berks.vendor' do
        expect(knife).to receive(:run_berks_install)
        expect(knife).to receive(:run_command).with("berks vendor #{File.join(docker_context, 'chef', 'cookbooks')}")
        knife.run_berks_vendor
      end
    end
  end

  describe '#run_berks_upload' do
    before(:each) do
     Chef::Config.reset
     Chef::Config[:chef_repo_path] = tempdir
     Chef::Config[:knife][:dockerfiles_path] = default_dockerfiles_path
     allow(knife).to receive(:docker_context).and_return(File.join(default_dockerfiles_path, 'docker', 'demo'))
     allow(knife).to receive(:run_berks_install)
    end

    let(:docker_context) { File.join(Chef::Config[:knife][:dockerfiles_path], 'docker', 'local') }

    context 'by default' do
      before do
        knife.config[:force_build] = false
      end

      it 'should call berks install' do
        allow(knife).to receive(:run_command).with('berks upload')
        expect(knife).to receive(:run_berks_install)
        knife.run_berks_upload
      end

      it 'should run berks upload' do
        expect(knife).to receive(:run_command).with('berks upload')
        knife.run_berks_upload
      end
    end

    context 'when force-build is specified' do
      before do
        knife.config[:force_build] = true
      end

      it 'should run berks upload with force' do
        expect(knife).to receive(:run_command).with('berks upload --force')
        knife.run_berks_upload
      end
    end

    context 'when berks-config is specified' do
      before do
        knife.config[:berks_config] = 'my_berkshelf/config.json'
        allow(File).to receive(:exist?).with('my_berkshelf/config.json').and_return(true)
        allow(File).to receive(:expand_path).with('my_berkshelf/config.json').and_return('/home/my_berkshelf/config.json')
      end

      it 'should run berks upload with specified config file' do
        expect(knife).to receive(:run_command).with('berks upload --config=/home/my_berkshelf/config.json')
        knife.run_berks_upload
      end
    end

    context 'when berks-config _and_ force-build is specified' do
      before do
        knife.config[:force_build] = true
        knife.config[:berks_config] = 'my_berkshelf/config.json'
        allow(File).to receive(:exist?).with('my_berkshelf/config.json').and_return(true)
        allow(File).to receive(:expand_path).with('my_berkshelf/config.json').and_return('/home/my_berkshelf/config.json')
      end

      it 'should run berks upload with specified config file _and_ force flag' do
        expect(knife).to receive(:run_command).with('berks upload --force --config=/home/my_berkshelf/config.json')
        knife.run_berks_upload
      end
    end
  end

  describe '#dockerfile_name' do
    it 'encodes the dockerfile name' do
      expect(knife).to receive(:parse_dockerfile_name)
      knife.dockerfile_name
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
