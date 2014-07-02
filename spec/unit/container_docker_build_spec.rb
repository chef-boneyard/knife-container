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
      c.stub(:output).and_return(true)
    end
  end

  describe "#run" do

    context "by default" do
      let(:argv) { %w[ docker/demo ] }

      it 'should parse argv, run berks and build image' do
        knife.should_receive(:read_and_validate_params).and_call_original
        knife.should_receive(:setup_config_defaults).and_call_original
        knife.should_receive(:run_berks)
        knife.should_receive(:build_image)
        knife.run
      end
    end

    context "--no-berks is passed" do
      let(:argv) { %w[ docker/demo --no-berks ] }

      it 'should parse argv, run berks and build image' do
        knife.should_receive(:read_and_validate_params).and_call_original
        knife.should_receive(:setup_config_defaults).and_call_original
        knife.should_not_receive(:run_berks)
        knife.should_receive(:build_image)
        knife.run
      end
    end
  end

  describe '#read_and_validate_params' do
    let(:argv) { %W[] }

    context 'argv is empty' do
      it 'should should print usage and exit' do
        knife.should_receive(:show_usage)
        knife.ui.should_receive(:fatal)
        lambda { knife.read_and_validate_params }.should raise_error(SystemExit)
      end
    end

    context "--no-berks was not passed" do
      let(:argv) { %w[ docker/demo ] }

      context "and Berkshelf is not installed" do
        let(:berks_output) { double("berks -v output", stdout: "berks not found") }
        
        before do
          knife.stub(:shell_out).with("berks -v").and_return(berks_output)
        end

        it 'should set run_berks to false' do
          knife.read_and_validate_params
          knife.config[:run_berks].should eql(false)
        end
      end

      context "and Berkshelf is installed" do
        let(:berks_output) { double("berks -v output", stdout: "3.1.1") }

        it 'should set run_berks to true' do
          knife.read_and_validate_params
          knife.config[:run_berks].should eql(true)
        end
      end
    end
  end

  describe '#setup_config_defaults' do
    before do
      Chef::Config.reset
      Chef::Config[:chef_repo_path] = tempdir
    end

    let(:argv) { %w[ docker/demo ]}

    context 'Chef::Config[:dockerfiles_path] has not been set' do
      it 'sets dockerfiles_path to Chef::Config[:chef_repo_path]/dockerfiles' do
        $stdout.stub(:write)
        knife.setup_config_defaults
        knife.config[:dockerfiles_path].should eql("#{Chef::Config[:chef_repo_path]}/dockerfiles")
      end
    end
  end

  describe "#run_berks" do

    let(:argv) { %W[ docker/local ] }

    before(:each) do
     Chef::Config.reset
     Chef::Config[:chef_repo_path] = tempdir
     Chef::Config[:knife][:dockerfiles_path] = default_dockerfiles_path
    end

    let(:docker_context) { File.join(Chef::Config[:knife][:dockerfiles_path], 'docker', 'local') }

    context "when there is no Berksfile" do
      before { knife.stub(:berksfile_exists?).and_return(false) }

      it "returns doing nothing" do
        knife.should_not_receive(:run_berks_vendor)
        knife.should_not_receive(:run_berks_upload)
        knife.run_berks
      end
    end

    context "when docker image was init in local mode" do
      before do
        File.stub(:exists?).with(File.join(docker_context, 'chef', 'zero.rb')).and_return(true)
        File.stub(:exists?).with(File.join(docker_context, 'chef', 'client.rb')).and_return(false)
        knife.stub(:chef_repo).and_return(File.join(docker_context, "chef"))
        knife.stub(:berksfile_exists?).and_return(true)
      end

      it 'should call run_berks_vendor' do
        knife.should_receive(:run_berks_vendor)
        knife.run_berks
      end
    end

    context "when docker image was init in client mode" do
      before do
        File.stub(:exists?).with(File.join(docker_context, 'chef', 'zero.rb')).and_return(false)
        File.stub(:exists?).with(File.join(docker_context, 'chef', 'client.rb')).and_return(true)
        knife.stub(:chef_repo).and_return(File.join(docker_context, "chef"))
        knife.stub(:berksfile_exists?).and_return(true)
      end

      it 'should call run_berks_upload' do
        knife.should_receive(:run_berks_upload)
        knife.run_berks
      end
    end
  end

  describe "#run_berks_install" do
    it "should call `berks install`" do
      knife.should_receive(:run_command).with("berks install")
      knife.run_berks_install
    end
  end

  describe "#run_berks_vendor" do

    before(:each) do
     Chef::Config.reset
     Chef::Config[:chef_repo_path] = tempdir
     Chef::Config[:knife][:dockerfiles_path] = default_dockerfiles_path
     knife.stub(:docker_context).and_return(File.join(default_dockerfiles_path, 'docker', 'demo'))
     knife.stub(:run_berks_install)
    end

    let(:docker_context) { File.join(Chef::Config[:knife][:dockerfiles_path], 'docker', 'demo') }

    context "cookbooks directory already exists in docker context" do
      before do
        File.stub(:exists?).with(File.join(docker_context, 'chef', 'cookbooks')).and_return(true)
      end
      
      context "and force-build was specified" do
        let(:argv) { %w[ docker/demo --force ]}

        it "should delete the existing cookbooks directory and run berks.vendor" do
          FileUtils.should_receive(:rm_rf).with(File.join(docker_context, 'chef', 'cookbooks'))
          knife.should_receive(:run_berks_install)
          knife.should_receive(:run_command).with("berks vendor #{File.join(docker_context, 'chef')}")
          knife.run_berks_vendor
        end

      end

      context "and force-build was not specified" do
        let(:argv) { %w[ docker-demo ] }
        
        it "should error out" do
          $stdout.stub(:write)
          $stderr.stub(:write)
          lambda { knife.run_berks_vendor }.should raise_error(SystemExit)
        end
      end
    end

    context "cookobooks directory does not yet exist" do
      before do
        File.stub(:exists?).with(File.join(docker_context, 'chef', 'cookbooks')).and_return(false)
      end

      it "should call berks.vendor" do
        knife.should_receive(:run_berks_install)
        knife.should_receive(:run_command).with("berks vendor #{File.join(docker_context, 'chef')}")
        knife.run_berks_vendor
      end
    end
  end

  describe "#run_berks_upload" do
    before(:each) do
     Chef::Config.reset
     Chef::Config[:chef_repo_path] = tempdir
     Chef::Config[:knife][:dockerfiles_path] = default_dockerfiles_path
     knife.stub(:docker_context).and_return(File.join(default_dockerfiles_path, 'docker', 'demo'))
     knife.stub(:run_berks_install)
    end

    let(:docker_context) { File.join(Chef::Config[:knife][:dockerfiles_path], 'docker', 'local') }

    context "by default" do
      before do
        knife.config[:force_build] = false
      end

      it "should call berks install" do
        knife.should_receive(:run_berks_install)
        knife.run_berks_upload
      end

      it "should run berks upload" do
        knife.should_receive(:run_command).with("berks upload")
        knife.run_berks_upload
      end
    end

    context "when force-build is specified" do
      before do
        knife.config[:force_build] = true
      end

      it "should run berks upload with force" do
        knife.should_receive(:run_command).with("berks upload --force")
        knife.run_berks_upload
      end
    end
  end

  describe "#docker_build_command" do
    let(:argv) { %W[ docker/demo ] }

    before(:each) do
     knife.config[:dockerfiles_path] = default_dockerfiles_path
    end

    it "should return valid command" do
      expect(knife.docker_build_command).to eql("CHEF_NODE_NAME='docker/demo-build' docker build -t docker/demo #{default_dockerfiles_path}/docker/demo")
    end
  end
end
