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
require 'chef/knife/container_docker_init'

describe Chef::Knife::ContainerDockerInit do

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
    @knife = Chef::Knife::ContainerDockerInit.new(argv)
    @knife.stub(:output).and_return(true)
    @knife.stub(:download_and_tag_base_image)
    KnifeContainer::Generator.reset
  end

  describe '#run' do
    let(:argv) { %w[ docker/demo ] }
    it "should run things" do
      @knife.should_receive(:read_and_validate_params)
      @knife.should_receive(:set_config_defaults)
      @knife.should_receive(:setup_context)
      @knife.chef_runner.should_receive(:converge)
      @knife.should_receive(:eval_current_system)
      @knife.should_receive(:download_and_tag_base_image)
      @knife.run
    end
  end

  describe 'when reading and validating parameters' do

    let(:argv) { %W[] }

    it 'should should print usage and exit when given no arguments' do
      @knife.should_receive(:show_usage)
      @knife.ui.should_receive(:fatal)
      lambda { @knife.run }.should raise_error(SystemExit)
    end

    context 'and using berkshelf functionality' do

      let(:argv) { %W[
        docker/demo
        -b
      ]}

      it 'loads berkshelf if available' do
        @knife.read_and_validate_params
        defined?(Berkshelf).should == "constant"
      end
    end
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

      context 'when cookbook_path is an array' do
        before do
          Chef::Config[:cookbook_path] = ['/path/to/cookbooks/', '/path/to/site-cookbooks']
        end

        it 'honors the array' do
          @knife.read_and_validate_params
          @knife.set_config_defaults
          @knife.setup_context
          expect(generator_context.cookbook_path).to eq(Chef::Config[:cookbook_path])
        end
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

      it 'sets the default base_image to chef/ubuntu-12.04:latest' do
        @knife.read_and_validate_params
        @knife.set_config_defaults
        @knife.setup_context
        expect(generator_context.base_image).to eq("chef/ubuntu-12.04:latest")
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
        first_boot = { run_list: ["recipe[apt]", "recipe[nginx]"]}
        expect(generator_context.first_boot).to include(JSON.pretty_generate(first_boot))
      end
    end
  end

  describe 'when using Berkshelf' do

    before(:each) do
     Chef::Config.reset
     Chef::Config[:chef_repo_path] = tempdir
    end

    context 'with -b passed as an argument' do
      let(:argv) { %W[
        docker/demo
        -r recipe[nginx]
        -z
        -b
      ]}

      it 'generates a Berksfile based on the run_list' do
        Dir.chdir(Chef::Config[:chef_repo_path]) do
          @knife.chef_runner.stub(:stdout).and_return(stdout_io)
          @knife.run
        end
        File.read("#{Chef::Config[:chef_repo_path]}/dockerfiles/docker/demo/Berksfile").should include 'cookbook "nginx"'
      end

      context 'when run_list includes fully-qualified recipe name' do
        let(:argv) { %W[
          docker/demo
          -r role[demo],recipe[demo::recipe],recipe[nginx]
          -z
          -b
        ]}

        it 'correctly configures Berksfile with just cookbook name' do
          Dir.chdir(Chef::Config[:chef_repo_path]) do
            @knife.chef_runner.stub(:stdout).and_return(stdout_io)
            @knife.run
          end
          File.read("#{Chef::Config[:chef_repo_path]}/dockerfiles/docker/demo/Berksfile").should include 'cookbook "demo"'
          File.read("#{Chef::Config[:chef_repo_path]}/dockerfiles/docker/demo/Berksfile").should include 'cookbook "nginx"'
        end
      end
    end
  end

  describe 'creating the Dockerfile' do
    let(:argv) { %W[
      docker/demo
      -f chef/ubuntu-12.04:latest
    ]}

    it 'should set the base_image name in a comment in the Dockerfile' do
      expect(File.read("#{Chef::Config[:chef_repo_path]}/dockerfiles/docker/demo/Dockerfile")).to include '# BASE chef/ubuntu-12.04:latest'
    end
  end

  describe "when executed without a valid cookbook path" do
    before(:each) do
     Chef::Config.reset
     Chef::Config[:chef_repo_path] = tempdir
    end

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
      expect(stdout).to include('log[Could not find a \'/tmp/nil/cookbooks\' directory in your chef-repo.] action write')
    end
  end

  describe "when copying cookbooks to temporary chef-repo" do

    context "when config specifies multiple directories" do
      before(:each) do
        Chef::Config.reset
        Chef::Config[:chef_repo_path] = tempdir
        Chef::Config[:cookbook_path] = ["#{fixtures_path}/cookbooks", "#{fixtures_path}/site-cookbooks"]
      end

      let(:argv) { %W[
        docker/demo
        -r recipe[nginx],recipe[apt]
        -z
      ]}

      it "should copy cookbooks from both directories" do
        @knife.chef_runner.stub(:stdout).and_return(stdout_io)
        @knife.run
        expect(stdout).to include("execute[cp -rf #{fixtures_path}/cookbooks/nginx #{tempdir}/dockerfiles/docker/demo/chef/cookbooks/] action run")
        expect(stdout).to include("execute[cp -rf #{fixtures_path}/site-cookbooks/apt #{tempdir}/dockerfiles/docker/demo/chef/cookbooks/] action run")
      end
    end
  end

  describe "when executed in local mode" do
    before(:each) do
     Chef::Config.reset
     Chef::Config[:chef_repo_path] = tempdir
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
        chef/ohai/hints
        chef/ohai_plugins/docker_container.rb
      ]
    end

    let(:expected_files) do
      expected_container_file_relpaths.map do |relpath|
        File.join(Chef::Config[:chef_repo_path], "dockerfiles", "docker/demo", relpath)
      end
    end

    it "configures the Generator context" do
      @knife.read_and_validate_params
      @knife.set_config_defaults
      @knife.setup_context
      expect(generator_context.dockerfile_name).to eq("docker/demo")
      expect(generator_context.dockerfiles_path).to eq("#{Chef::Config[:chef_repo_path]}/dockerfiles")
      expect(generator_context.cookbook_path).to eq([default_cookbook_path])
      expect(generator_context.base_image).to eq("chef/ubuntu-12.04:latest")
      expect(generator_context.chef_client_mode).to eq("zero")
      expect(generator_context.run_list).to eq(%w[recipe[nginx]])
      expect(generator_context.generate_berksfile).to eq(true)
    end

    it "creates a folder to manage the Dockerfile and Chef files" do
      Dir.chdir(Chef::Config[:chef_repo_path]) do
        @knife.chef_runner.stub(:stdout).and_return(stdout_io)
        @knife.run
      end
      generated_files = Dir.glob("#{Chef::Config[:chef_repo_path]}/dockerfiles/docker/demo/**{,/*/**}/*", File::FNM_DOTMATCH)
      expected_files.each do |expected_file|
        expect(generated_files).to include(expected_file)
      end
    end

    it "only copies cookbooks that exist in the run_list" do
      Dir.chdir(Chef::Config[:chef_repo_path]) do
        @knife.chef_runner.stub(:stdout).and_return(stdout_io)
        @knife.run
        expect(stdout).to include("execute[cp -rf #{default_cookbook_path}/nginx #{Chef::Config[:chef_repo_path]}/dockerfiles/docker/demo/chef/cookbooks/] action run")
        expect(stdout).not_to include("execute[cp -rf #{default_cookbook_path}/dummy #{Chef::Config[:chef_repo_path]}/dockerfiles/docker/demo/chef/cookbooks/] action run")
      end
    end
  end

  describe "executed in server mode" do
    before do
     Chef::Config.reset
     Chef::Config[:chef_repo_path] = tempdir
     Chef::Config[:trusted_certs_dir] = File.join(fixtures_path, ".chef", "trusted_certs")
     Chef::Config[:encrypted_data_bag_secret] = File.join(fixtures_path, ".chef", "encrypted_data_bag_secret")
    end

    let(:argv) { %W[
      docker/demo
      -f chef/ubuntu-12.04:11.12.8
      --cookbook-path #{default_cookbook_path}
      -r recipe[nginx]
      -d #{tempdir}/dockerfiles
      --validation-key #{fixtures_path}/.chef/validation.pem
      --validation-client-name masterchef
      --server-url http://localhost:4000
      --secret-file #{fixtures_path}/.chef/encrypted_data_bag_secret
    ]}

    let(:expected_container_file_relpaths) do
      %w[
        Dockerfile
        chef/first-boot.json
        chef/client.rb
        chef/validation.pem
        chef/ohai/hints
        chef/ohai_plugins/docker_container.rb
        chef/trusted_certs/chef_example_com.crt
        chef/encrypted_data_bag_secret
      ]
    end

    let(:expected_files) do
      expected_container_file_relpaths.map do |relpath|
        File.join(Chef::Config[:chef_repo_path], "dockerfiles", "docker/demo", relpath)
      end
    end

    subject(:docker_init) { Chef::Knife::DockerInit.new(argv) }

    it "configures the Generator context" do
      @knife.read_and_validate_params
      @knife.set_config_defaults
      @knife.setup_context
      expect(generator_context.dockerfile_name).to eq("docker/demo")
      expect(generator_context.dockerfiles_path).to eq("#{Chef::Config[:chef_repo_path]}/dockerfiles")
      expect(generator_context.base_image).to eq("chef/ubuntu-12.04:11.12.8")
      expect(generator_context.chef_client_mode).to eq("client")
      expect(generator_context.run_list).to eq(%w[recipe[nginx]])
      expect(generator_context.chef_server_url).to eq("http://localhost:4000")
      expect(generator_context.validation_client_name).to eq("masterchef")
      expect(generator_context.validation_key).to eq("#{fixtures_path}/.chef/validation.pem")
      expect(generator_context.trusted_certs_dir).to eq("#{fixtures_path}/.chef/trusted_certs")
      expect(generator_context.encrypted_data_bag_secret).to eq("#{fixtures_path}/.chef/encrypted_data_bag_secret")
    end

    it "creates a folder to manage the Dockerfile and Chef files" do
      Dir.chdir(Chef::Config[:chef_repo_path]) do
        @knife.chef_runner.stub(:stdout).and_return(stdout_io)
        @knife.run
      end
      generated_files = Dir.glob("#{Chef::Config[:chef_repo_path]}/dockerfiles/docker/demo/**{,/*/**}/*", File::FNM_DOTMATCH)
      expected_files.each do |expected_file|
        expect(generated_files).to include(expected_file)
      end
    end
  end

  describe "#download_and_tag_base_image" do
    before { @knife.unstub(:download_and_tag_base_image) }
    let(:argv) { %w[ docker/demo ] }
    it "should run docker pull on the specified base image and tag it with the dockerfile name" do
      @knife.should_receive(:shell_out).with("docker pull chef/ubuntu-12.04:latest")
      @knife.should_receive(:shell_out).with("docker tag chef/ubuntu-12.04:latest docker/demo")
      @knife.read_and_validate_params
      @knife.set_config_defaults
      @knife.download_and_tag_base_image
    end
  end

  describe '#eval_current_system' do
    let(:argv) { %w[ docker/demo ] }

    context 'the context already exists' do
      before do
        Chef::Config.reset
        Chef::Config[:chef_repo_path] = tempdir
        File.stub(:exists?).with(File.join(Chef::Config[:chef_repo_path], 'dockerfiles', 'docker', 'demo')).and_return(true)
        @knife.config[:dockerfiles_path] = File.join(Chef::Config[:chef_repo_path], 'dockerfiles')
      end

      it 'should warn the user if the context they are trying to create already exists' do
        @knife.should_receive(:show_usage)
        @knife.ui.should_receive(:fatal)
        lambda { @knife.eval_current_system }.should raise_error(SystemExit)
      end
    end

    context 'the context already exists but the force flag was specified' do
      let(:argv) { %w[ docker/demo --force ] }

      before do
        Chef::Config.reset
        Chef::Config[:chef_repo_path] = tempdir
        File.stub(:exists?).with(File.join(Chef::Config[:chef_repo_path], 'dockerfiles', 'docker', 'demo')).and_return(true)
        @knife.config[:dockerfiles_path] = File.join(Chef::Config[:chef_repo_path], 'dockerfiles')
      end

      it 'should delete that folder and proceed as normal' do
        FileUtils.should_receive(:rm_rf).with(File.join(Chef::Config[:chef_repo_path], 'dockerfiles', 'docker', 'demo'))
        @knife.eval_current_system
      end
    end
  end
end
