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
      allow(c).to receive(:output).and_return(true)
      c.parse_options(argv)
      c.merge_configs
    end
  end

  describe '#run' do
    let(:argv) { %w[ docker/demo ] }

    it 'parses arguments, redownload and retags the docker image, then runs DockerBuild' do
      expect(knife).to receive(:validate)
      expect(knife).to receive(:setup_config_defaults)
      expect(knife).to receive(:rebase_docker_image)
      expect(knife).to receive(:run_build_image)
      knife.run
    end
  end

  describe '#rebase_docker_image' do
    let(:argv) { %w[ docker/demo ] }
    let(:image) { double('Docker Image', rebase: nil) }

    it 'creates a Docker Image object based on a context and rebases it' do
      expect(KnifeContainer::Plugins::Docker::Image).to receive(:new).and_return(image)
      expect(image).to receive(:rebase)
      knife.rebase_docker_image
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
