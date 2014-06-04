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
require 'chef/knife/docker_init'

describe Chef::Knife::DockerInit do

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
    @knife = Chef::Knife::DockerInit.new(argv)
    @knife.stub(:output).and_return(true)
    KnifeContainer::Generator.reset
  end

  describe 'when reading and validating parameters' do

    let(:argv) { %W[] }

    it 'should should print usage and exit when given no arguments' do
      @knife.should_receive(:show_usage)
      @knife.ui.should_receive(:fatal)
      lambda { @knife.run }.should raise_error(SystemExit)
    end

    it 'checks to see if berkshelf is installed if using berkshelf functionality'
  end

  describe 'when setting config defaults' do
    before do
     Chef::Config.reset
     Chef::Config[:chef_repo_path] = tempdir
    end

    let(:argv) { %W[
      docker/demo
    ]}

    context 'when no cli overrides have been specified' do
      it 'sets validation_key to Chef::Config value' do
        @knife.read_and_validate_params
        @knife.set_config_defaults
        @knife.setup_context
        expect(generator_context.validation_key).to eq(Chef::Config[:validation_key])
      end
      it 'sets validation_client_name to Chef::Config value' do
        @knife.read_and_validate_params
        @knife.set_config_defaults
        @knife.setup_context
        expect(generator_context.validation_client_name).to eq(Chef::Config[:validation_client_name])
      end
      it 'sets chef_server_url to Chef::Config value' do
        @knife.read_and_validate_params
        @knife.set_config_defaults
        @knife.setup_context
        expect(generator_context.chef_server_url).to eq(Chef::Config[:chef_server_url])
      end
      it 'sets cookbook_path to Chef::Config value' do
        @knife.read_and_validate_params
        @knife.set_config_defaults
        @knife.setup_context
        expect(generator_context.cookbook_path).to eq(Chef::Config[:cookbook_path])
      end
      it 'sets node_path to Chef::Config value' do
        @knife.read_and_validate_params
        @knife.set_config_defaults
        @knife.setup_context
        expect(generator_context.node_path).to eq(Chef::Config[:node_path])
      end
      it 'sets role_path to Chef::Config value' do
        @knife.read_and_validate_params
        @knife.set_config_defaults
        @knife.setup_context
        expect(generator_context.role_path).to eq(Chef::Config[:role_path])
      end
      it 'sets environment_path to Chef::Config value' do
        @knife.read_and_validate_params
        @knife.set_config_defaults
        @knife.setup_context
        expect(generator_context.environment_path).to eq(Chef::Config[:environment_path])
      end
      it 'sets dockerfiles_path to Chef::Config[:knife][:dockerfiles_path]' do
        Chef::Config[:knife][:dockerfiles_path] = '/var/chef/dockerfiles'
        @knife.read_and_validate_params
        @knife.set_config_defaults
        @knife.setup_context
        expect(generator_context.dockerfiles_path).to eq("/var/chef/dockerfiles")
      end

      context 'when Chef::Config[:dockerfiles_path] has not been set' do
        it 'sets dockerfiles_path to Chef::Config[:chef_repo_path]/dockerfiles' do
          @knife.read_and_validate_params
          @knife.set_config_defaults
          @knife.setup_context
          expect(generator_context.dockerfiles_path).to eq("#{Chef::Config[:chef_repo_path]}/dockerfiles")
        end
      end
    end
  end

  describe 'when setting up the generator context' do

    before do
     Chef::Config.reset
     Chef::Config[:chef_repo_path] = tempdir
    end

    context 'with defaults only' do
      let(:argv) { %W[
        docker/demo
      ]}

      it 'sets the default base_image to chef/ubuntu_12.04' do
        @knife.read_and_validate_params
        @knife.set_config_defaults
        @knife.setup_context
        expect(generator_context.base_image).to eq("chef/ubuntu_12.04")
      end
      it 'sets the runlist to an empty array' do
        @knife.read_and_validate_params
        @knife.set_config_defaults
        @knife.setup_context
        expect(generator_context.run_list).to eq([])
      end        
      it 'sets chef_client_mode to client' do
        @knife.read_and_validate_params
        @knife.set_config_defaults
        @knife.setup_context
        expect(generator_context.chef_client_mode).to eq("client")
      end
    end
    
    context 'while passing a run list' do
      let(:argv) { %W[
        docker/demo
        -r recipe[apt],recipe[nginx]
      ]}

      it 'should add the run_list value to the first_boot.json if passed' do
        @knife.read_and_validate_params
        @knife.set_config_defaults
        @knife.setup_context
        expect(generator_context.first_boot).to include("run_list"=>["recipe[apt]","recipe[nginx]"])
      end
    end
  end

  describe 'first_value' do
    it 'should return the first value of an array if an array is passed in'
    it 'should return the full string if a string is passed in'
  end

  describe 'when using Berkshelf' do

    before do
     Chef::Config.reset
     Chef::Config[:chef_repo_path] = tempdir
    end

    context 'with -b is specified with no value' do
      let(:argv) { %W[
        docker/demo
        -b
      ]}

      it 'generates a Berksfile based on the run_list'
    end

    context 'with a filepath specified with the -b flag' do
      let(:argv) { %W[
        docker/demo
        -b Berksfile
      ]}

      it "copies an existing Berksfile when a filepath is specified with the -b flag"
    end
  end

  describe "when executed in local mode" do
    before do
     Chef::Config.reset
     Chef::Config[:chef_repo_path] = tempdir
    end

    context "without a valid cookbook path" do
      let(:argv) { %W[
        docker/demo
        -r recipe[nginx]
        -z
        -b
      ]}

      it "should log an error and not copy cookbooks" do
        Chef::Config[:cookbook_path] = '/tmp/nil/cookbooks'
        @knife.chef_runner.stub(:stdout).and_return(stdout_io)
        @knife.run
        expect(stdout).to include('log[Source cookbook directory not found.] action write')
      end      
    end
    let(:argv) { %W[
      docker/demo
      --cookbook-path #{default_cookbook_path}
      -r recipe[nginx]
      -z
      -b
    ]}
    
    let(:expected_container_file_relpaths) do
      %w[
        Dockerfile
        Berksfile
        chef/first-boot.json
        chef/zero.rb
      ]
    end

    let(:expected_files) do
      expected_container_file_relpaths.map do |relpath|
        File.join(Chef::Config[:chef_repo_path], "dockerfiles", "docker/demo", relpath)
      end
    end

    subject(:docker_init) { Chef::Knife::DockerInit.new(argv) }

    it "configures the Generator context" do
      docker_init.read_and_validate_params
      docker_init.set_config_defaults
      docker_init.setup_context
      expect(generator_context.dockerfile_name).to eq("docker/demo")
      expect(generator_context.dockerfiles_path).to eq("#{Chef::Config[:chef_repo_path]}/dockerfiles")
      expect(generator_context.base_image).to eq("chef/ubuntu_12.04")
      expect(generator_context.chef_client_mode).to eq("zero")
      expect(generator_context.run_list).to eq(%w[recipe[nginx]])
      expect(generator_context.berksfile).to eq("#{fixtures_path}/Berksfile")
    end

    it "creates a folder to manage the Dockerfile and Chef files" do
      Dir.chdir(Chef::Config[:chef_repo_path]) do
        docker_init.chef_runner.stub(:stdout).and_return(stdout_io)
        docker_init.run
      end
      generated_files = Dir.glob("#{Chef::Config[:chef_repo_path]}/dockerfiles/docker/demo/**{,/*/**}/*", File::FNM_DOTMATCH)
      expected_files.each do |expected_file|
        expect(generated_files).to include(expected_file)
      end
    end
  end

  describe "executed in server mode" do
    before do
     Chef::Config.reset
     Chef::Config[:chef_repo_path] = tempdir
    end

    let(:argv) { %W[
      docker/demo
      -f ubuntu:12.04
      --cookbook-path #{default_cookbook_path}
      -r recipe[nginx]
      -d #{tempdir}/dockerfiles
      --validation-key #{fixtures_path}/.chef/validation.pem
      --validation-client-name masterchef
      --server-url http://localhost:4000
    ]}

    let(:expected_container_file_relpaths) do
      %w[
        Dockerfile
        chef/first-boot.json
        chef/client.rb
        chef/validation.pem
      ]
    end

    let(:expected_files) do
      expected_container_file_relpaths.map do |relpath|
        File.join(Chef::Config[:chef_repo_path], "dockerfiles", "docker/demo", relpath)
      end
    end
    
    subject(:docker_init) { Chef::Knife::DockerInit.new(argv) }

    it "configures the Generator context" do
      docker_init.read_and_validate_params
      docker_init.set_config_defaults
      docker_init.setup_context
      expect(generator_context.dockerfile_name).to eq("docker/demo")
      expect(generator_context.dockerfiles_path).to eq("#{Chef::Config[:chef_repo_path]}/dockerfiles")
      expect(generator_context.base_image).to eq("ubuntu:12.04")
      expect(generator_context.chef_client_mode).to eq("client")
      expect(generator_context.run_list).to eq(%w[recipe[nginx]])
      expect(generator_context.chef_server_url).to eq("http://localhost:4000")
      expect(generator_context.validation_client_name).to eq("masterchef")
      expect(generator_context.validation_key).to eq("#{fixtures_path}/.chef/validation.pem")
    end

    it "creates a folder to manage the Dockerfile and Chef files" do
      Dir.chdir(Chef::Config[:chef_repo_path]) do
        docker_init.chef_runner.stub(:stdout).and_return(stdout_io)
        docker_init.run
      end
      generated_files = Dir.glob("#{Chef::Config[:chef_repo_path]}/dockerfiles/docker/demo/**{,/*/**}/*", File::FNM_DOTMATCH)
      expected_files.each do |expected_file|
        expect(generated_files).to include(expected_file)
      end
    end
  end

end
