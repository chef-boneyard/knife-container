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
require 'chef/knife/docker_build'

describe Chef::Knife::DockerBuild do
  let(:stdout_io) { StringIO.new }
  let(:stderr_io) { StringIO.new }

  def stdout
    stdout_io.string
  end

  let(:default_cookbook_path) do
    File.expand_path("cookbooks", fixtures_path)
  end

  def generator_context
    KnifeContainer::Generator.context
  end

  before(:each) do
    @knife = Chef::Knife::DockerBuild.new(argv)
    @knife.stub(:output).and_return(true)
    KnifeContainer::Generator.reset
  end

  describe "#run" do
    let (:argv) { ['docker/demo'] }

    before do
      @knife.stub(:read_and_validate_params)
      @knife.stub(:setup_context)
      @knife.stub_chain(:chef_runner, :converge)
    end

    it 'should parse argv and run chef_runner' do
      @knife.should_receive(:read_and_validate_params)
      @knife.should_receive(:setup_config_defaults)
      @knife.should_receive(:setup_context)
      @knife.should_receive(:run_berks)
      @knife.should_receive(:build_image)
      @knife.run
    end
  end

  describe '#read_and_validate_params' do
    let(:argv) { %W[] }

    context 'argv is empty' do
      it 'should should print usage and exit' do
        @knife.should_receive(:show_usage)
        @knife.ui.should_receive(:fatal)
        lambda { @knife.run }.should raise_error(SystemExit)
      end
    end
  end

  describe '#setup_config_defaults' do
    before do
      Chef::Config.reset
      Chef::Config[:chef_repo_path] = tempdir
    end

    let(:argv) { %w[ docker/demo ]}

    context 'when Chef::Config[:dockerfiles_path] has not been set' do
      it 'sets dockerfiles_path to Chef::Config[:chef_repo_path]/dockerfiles' do
        @knife.run
        @knife.config[:dockerfiles_path].should eql("#{Chef::Config[:chef_repo_path]}/dockerfiles")
      end
    end

    context 'when no cli overrides have been specified' do
      it 'sets dockerfiles_path to Chef::Config'
    end
  end

end
