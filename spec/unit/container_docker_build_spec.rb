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
      c.stub(:output).and_return(true)
      c.parse_options(argv)
      c.merge_configs
    end
  end

  describe "#run" do
    before(:each) do
      knife.stub(:run_berks)
      knife.stub(:build_image)
      knife.stub(:cleanup_artifacts)
    end

    context "by default" do
      let(:argv) { %w[ docker/demo ] }
      before do
        knife.config[:run_berks] = true
        knife.config[:cleanup] = true
      end

      it 'should parse argv, run berkshelf, build the image and cleanup the artifacts' do
        expect(knife).to receive(:read_and_validate_params).and_call_original
        expect(knife).to receive(:setup_config_defaults).and_call_original
        expect(knife).to receive(:run_berks)
        expect(knife).to receive(:build_image)
        expect(knife).to receive(:cleanup_artifacts)
        knife.run
      end
    end

    context "--no-berks is passed" do
      let(:argv) { %w[ docker/demo --no-berks ] }
      before do
        knife.config[:run_berks] = false
        knife.config[:cleanup] = true
      end

      it 'should not run berkshelf' do
        knife.should_receive(:read_and_validate_params)
        knife.should_receive(:setup_config_defaults)
        expect(knife).not_to receive(:run_berks)
        knife.should_receive(:build_image)
        knife.should_receive(:cleanup_artifacts)
        knife.run
      end
    end

    context "--no-cleanup is passed" do
      let(:argv) { %w[ docker/demo --no-cleanup ] }
      before do
        knife.config[:run_berks] = true
        knife.config[:cleanup] = false
      end

      it 'should not clean up the artifacts' do
        knife.should_receive(:read_and_validate_params)
        knife.should_receive(:setup_config_defaults)
        knife.should_receive(:run_berks)
        knife.should_receive(:build_image)
        expect(knife).not_to receive(:cleanup_artifacts)
        knife.run
      end
    end
  end

  describe '#read_and_validate_params' do
    let(:argv) { %W[] }

    context 'argv is empty' do
      it 'should should print usage and exit' do
        expect(knife).to receive(:show_usage)
        expect(knife.ui).to receive(:fatal)
        expect { knife.run }.to raise_error(SystemExit)
      end
    end

    context "when Berkshelf is not installed" do
      let(:argv) { %w[ docker/demo ] }
      let(:berks_output) { double("berks -v output", stdout: "berks not found") }

      it 'should set config[:cleanup] to true' do
        knife.read_and_validate_params
        knife.config[:cleanup].should eql(true)
      end
    end

    context "--no-cleanup was passed" do
      let(:argv) { %w[ docker/demo --no-cleanup ] }

      it 'should set config[:cleanup] to false' do
        knife.read_and_validate_params
        knife.config[:cleanup].should eql(false)
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
        expect(knife.config[:run_berks]).to eql(false)
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

    context "when there is no Berksfile" do
      before { File.stub(:exists?).with(File.join(docker_context, 'Berksfile')).and_return(false) }

      it "returns doing nothing" do
        expect(knife).not_to receive(:run_berks_vendor)
        expect(knife).not_to receive(:run_berks_upload)
        knife.run_berks
      end
    end

    context "when docker image was init in local mode" do
      before do
        File.stub(:exists?).with(File.join(docker_context, 'Berksfile')).and_return(true)
        File.stub(:exists?).with(File.join(docker_context, 'chef', 'zero.rb')).and_return(true)
        File.stub(:exists?).with(File.join(docker_context, 'chef', 'client.rb')).and_return(false)
        knife.stub(:chef_repo).and_return(File.join(docker_context, "chef"))
      end

      it 'should call run_berks_vendor' do
        expect(knife).to receive(:run_berks_vendor)
        knife.run_berks
      end
    end

    context "when docker image was init in client mode" do
      before do
        File.stub(:exists?).with(File.join(docker_context, 'Berksfile')).and_return(true)
        File.stub(:exists?).with(File.join(docker_context, 'chef', 'zero.rb')).and_return(false)
        File.stub(:exists?).with(File.join(docker_context, 'chef', 'client.rb')).and_return(true)
        knife.stub(:chef_repo).and_return(File.join(docker_context, "chef"))
      end

      it 'should call run_berks_upload' do
        expect(knife).to receive(:run_berks_upload)
        knife.run_berks
      end
    end
  end

  describe "#run_berks_install" do
    it "should call `berks install`" do
      expect(knife).to receive(:run_command).with("berks install")
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
          expect(knife).to receive(:run_berks_install)
          expect(knife).to receive(:run_command).with("berks vendor #{File.join(docker_context, 'chef')}")
          knife.run_berks_vendor
        end

      end

      context "and force-build was not specified" do
        let(:argv) { %w[ docker-demo ] }

        it "should error out" do
          $stdout.stub(:write)
          $stderr.stub(:write)
          expect { knife.run_berks_vendor }.to raise_error(SystemExit)
        end
      end
    end

    context "cookobooks directory does not yet exist" do
      before do
        File.stub(:exists?).with(File.join(docker_context, 'chef', 'cookbooks')).and_return(false)
      end

      it "should call berks.vendor" do
        expect(knife).to receive(:run_berks_install)
        expect(knife).to receive(:run_command).with("berks vendor #{File.join(docker_context, 'chef')}")
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
        expect(knife).to receive(:run_berks_install)
        knife.run_berks_upload
      end

      it "should run berks upload" do
        expect(knife).to receive(:run_command).with("berks upload")
        knife.run_berks_upload
      end
    end

    context "when force-build is specified" do
      before do
        knife.config[:force_build] = true
      end

      it "should run berks upload with force" do
        expect(knife).to receive(:run_command).with("berks upload --force")
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

  describe "#cleanup_artifacts" do
    let(:argv) { %w[ docker/demo ] }

    context "running in server-mode" do
      it "should delete the node and client objects from the Chef Server" do
        expect(knife).to receive(:destroy_item).with(Chef::Node, 'docker/demo-build', 'node')
        expect(knife).to receive(:destroy_item).with(Chef::ApiClient, 'docker/demo-build', 'client')
        knife.cleanup_artifacts
      end
    end
  end
end
