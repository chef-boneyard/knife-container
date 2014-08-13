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
require 'chef/knife/container_docker_rebuild'
Chef::Knife::ContainerDockerRebuild.load_deps

describe Chef::Knife::ContainerDockerRebuild do

  let(:stdout_io) { StringIO.new }
  let(:stderr_io) { StringIO.new }

  def stdout
    stdout_io.string
  end

  let(:default_dockerfiles_path) do
    File.expand_path("dockerfiles", fixtures_path)
  end

  subject(:knife) do
    Chef::Knife::ContainerDockerRebuild.new(argv).tap do |c|
      c.stub(:output).and_return(true)
      c.parse_options(argv)
      c.merge_configs
    end
  end

  describe '#run' do
    let(:argv) { %w[ docker/demo ] }

    it 'parses arguments, redownload and retags the docker image, then runs DockerBuild' do
      expect(knife).to receive(:read_and_validate_params).and_call_original
      expect(knife).to receive(:setup_config_defaults).and_call_original
      expect(knife).to receive(:redownload_docker_image)
      expect(knife).to receive(:run_build_image)
      knife.run
    end
  end

  describe '#redownload_docker_image' do
    let(:argv) { %w[ docker/demo ] }

    before do
      allow(knife).to receive(:parse_dockerfile_for_base).and_return('chef/ubuntu-12.04:latest')
      allow(knife).to receive(:download_image).and_return('0123456789ABCDEF')
    end

    it 'parses the Dockerfile for BASE and pulls down that image' do
      expect(knife).to receive(:parse_dockerfile_for_base).and_return('chef/ubuntu-12.04:latest')
      expect(knife).to receive(:delete_image).with('docker/demo')
      expect(knife).to receive(:download_image).with('chef/ubuntu-12.04:latest').and_return('0123456789ABCDEF')
      expect(knife).to receive(:tag_image).with('0123456789ABCDEF', 'docker/demo')
      knife.redownload_docker_image
    end
  end

  describe '#parse_dockerfile_for_base' do
    let(:argv) { %w[ docker/demo ] }
    let(:valid_file_contents) { StringIO.new("# BASE chef/ubuntu-14.04:latest\nFROM docker/demo") }
    let(:invalid_file_contents) { StringIO.new("FROM docker/demo") }

    before { allow(File).to receive(:open).and_return(valid_file_contents) }

    it 'returns the BASE value from the file' do
      expect(knife.parse_dockerfile_for_base).to eql('chef/ubuntu-14.04:latest')
    end

    context 'when BASE is missing' do
      before do
        Chef::Config[:knife][:docker_image] = 'chef/centos-6:latest'
        allow(File).to receive(:open).and_return(invalid_file_contents)
      end

      it 'returns the default Chef::Config value' do
        expect(knife.parse_dockerfile_for_base).to eql('chef/centos-6:latest')
      end

      context 'and Chef::Config value is missing' do
        before do
          Chef::Config[:knife][:docker_image] = nil
          allow(File).to receive(:open).and_return(invalid_file_contents)
        end

        it 'returns chef/ubuntu-12.04' do
          expect(knife.parse_dockerfile_for_base).to eql('chef/ubuntu-12.04:latest')
        end
      end
    end
  end

  describe '#run_build_image' do
    let(:argv) { %w[ docker/demo ] }
    let(:obj) { double('Chef::Knife::ContainerDockerBuild#instance')}

    it 'calls Chef::Knife::ContainerDockerBuild' do
      expect(Chef::Knife::ContainerDockerBuild).to receive(:new).with(argv).and_return(obj)
      expect(obj).to receive(:run)
      knife.run_build_image
    end
  end
end
