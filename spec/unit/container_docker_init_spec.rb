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

  let(:reset_chef_config) do
    Chef::Config.reset
    Chef::Config[:chef_repo_path] = tempdir
    Chef::Config[:knife][:dockerfiles_path] = File.join(tempdir, 'dockerfiles')
    Chef::Config[:cookbook_path] = File.join(fixtures_path, 'cookbooks')
    Chef::Config[:chef_server_url] = "http://localhost:4000"
    Chef::Config[:validation_key] = File.join(fixtures_path, '.chef', 'validator.pem')
    Chef::Config[:trusted_certs_dir] = File.join(fixtures_path, '.chef', 'trusted_certs')
    Chef::Config[:validation_client_name] = 'masterchef'
    Chef::Config[:encrypted_data_bag_secret] = File.join(fixtures_path, '.chef', 'encrypted_data_bag_secret')
  end

  def generator_context
    KnifeContainer::Generator.context
  end

  before(:each) do
    @knife = Chef::Knife::ContainerDockerInit.new(argv)
    @knife.stub(:output).and_return(true)
    @knife.stub(:download_and_tag_base_image)
    @knife.ui.stub(:stdout).and_return(stdout_io)
    @knife.chef_runner.stub(:stdout).and_return(stdout_io)
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

  #
  # Validating parameters
  #
  describe 'when reading and validating parameters' do
    let(:argv) { %W[] }

    it 'should should print usage and exit when given no arguments' do
      @knife.should_receive(:show_usage)
      @knife.ui.should_receive(:fatal)
      lambda { @knife.run }.should raise_error(SystemExit)
    end

    context 'and using berkshelf functionality' do
      let(:argv) {%W[ docker/demo -b ]}

      it 'loads berkshelf if available' do
        @knife.read_and_validate_params
        defined?(Berkshelf).should == "constant"
      end
    end
  end

  #
  # Setting up the generator context
  #
  describe 'when setting up the generator context' do
    before(:each) { reset_chef_config }

    context 'when no cli overrides have been specified' do
      let(:argv) { %w[ docker/demo ] }

      it 'should set values to Chef::Config default values' do
        @knife.run
        expect(generator_context.chef_server_url).to eq("http://localhost:4000")
        expect(generator_context.cookbook_path).to eq(File.join(fixtures_path, 'cookbooks'))
        expect(generator_context.chef_client_mode).to eq("client")
        expect(generator_context.node_path).to eq(File.join(tempdir, 'nodes'))
        expect(generator_context.role_path).to eq(File.join(tempdir, 'roles'))
        expect(generator_context.environment_path).to eq(File.join(tempdir, 'environments'))
        expect(generator_context.dockerfiles_path).to eq(File.join(tempdir, 'dockerfiles'))
        expect(generator_context.run_list).to eq([])
      end

      context 'when cookbook_path is an array' do
        before do
          Chef::Config[:cookbook_path] = ['/path/to/cookbooks', '/path/to/site-cookbooks']
        end

        it 'honors the array' do
          @knife.run
          expect(generator_context.cookbook_path).to eq(['/path/to/cookbooks', '/path/to/site-cookbooks'])
        end
      end
    end

    describe "when base image is specified" do
      context "with a tag" do
        let(:argv) { %w[ docker/demo -f docker/demo:11.12.8 ] }

        it "should respect that tag" do
          @knife.run
          expect(generator_context.base_image).to eql("docker/demo:11.12.8")
        end
      end

      context "without a tag" do
        let(:argv) { %w[ docker/demo -f docker/demo ] }

        it "should append the 'latest' tag on the name" do
          @knife.run
          expect(generator_context.base_image).to eql("docker/demo:latest")
        end
      end
    end

    describe 'when passing a run list' do
      let(:argv) { %W[
        docker/demo
        -r recipe[apt],recipe[nginx]
      ]}

      it 'should add the run_list value to the first_boot.json if passed' do
        @knife.run
        first_boot = { run_list: ["recipe[apt]", "recipe[nginx]"]}
        expect(generator_context.first_boot).to include(JSON.pretty_generate(first_boot))
      end
    end

    describe 'when local-mode is specified' do
      let(:argv) { %w[ docker/demo -z ] }

      it "sets generator_context.chef_client_mode to zero" do
        @knife.run
        expect(generator_context.chef_client_mode).to eq("zero")
      end
    end
  end


  #
  # The chef runner converge
  #
  describe 'the converge phase' do
    describe 'when the -b flag is specified' do
      before(:each) { reset_chef_config }
      let(:argv) { %w[ docker/demo -r recipe[nginx] -z -b ] }

      subject(:berksfile) do
        File.read("#{tempdir}/dockerfiles/docker/demo/Berksfile")
      end

      it 'generates a Berksfile based on the run_list' do
        @knife.run
        berksfile.should include 'cookbook "nginx"'
      end

      context 'and the run_list includes fully-qualified recipe names' do
        let(:argv) { %W[
          docker/demo
          -r role[demo],recipe[demo::recipe],recipe[nginx]
          -z -b
        ]}

        it 'correctly configures Berksfile with just the cookbook name' do
          @knife.run
          berksfile.should include 'cookbook "demo"'
          berksfile.should include 'cookbook "nginx"'
        end
      end
    end

    describe 'when creating the client config file' do
      context 'for server-mode' do
        before { reset_chef_config }
        let(:argv) {%W[ docker/demo ]}

        subject(:config_file) do
          File.read("#{tempdir}/dockerfiles/docker/demo/chef/client.rb")
        end

        it 'should have some global settings' do
          @knife.run
          expect(config_file).to include "require 'chef-init'"
          expect(config_file).to include "node_name", "ChefInit.node_name"
          expect(config_file).to include "ssl_verify_mode", ":verify_peer"
          expect(config_file).to include "chef_server_url", "http://localhost:4000"
          expect(config_file).to include "validation_key", "/etc/chef/secure/validation.pem"
          expect(config_file).to include "client_key", "/etc/chef/secure/client.pem"
          expect(config_file).to include "trusted_certs_dir", "/etc/chef/secure/trusted_certs"
          expect(config_file).to include "validation_client_name", "masterchef"
          expect(config_file).to include "encrypted_data_bag_secret", "/etc/chef/secure/encrypted_data_bag_secret"
        end
      end

      context 'for local-mode' do
        before { reset_chef_config }
        let(:argv) {%W[ docker/demo -z ]}

        subject(:config_file) do
          File.read("#{tempdir}/dockerfiles/docker/demo/chef/zero.rb")
        end

        it 'should include local-mode specific settings' do
          @knife.run
          expect(config_file).to include "require 'chef-init'"
          expect(config_file).to include "node_name", "ChefInit.node_name"
          expect(config_file).to include "ssl_verify_mode", ":verify_peer"
          expect(config_file).to include "cookbook_path", "[\"/etc/chef/cookbooks\"]"
          expect(config_file).to include "encrypted_data_bag_secret", "/etc/chef/secure/encrypted_data_bag_secret"
        end
      end

      context 'when encrypted_data_bag_secret is not specified' do
        before do
          reset_chef_config
          Chef::Config[:encrypted_data_bag_secret] = nil
        end

        let(:argv) {%W[ docker/demo ]}

        subject(:config_file) do
          File.read("#{tempdir}/dockerfiles/docker/demo/chef/client.rb")
        end

        it 'should not be present in config' do
          @knife.run
          expect(config_file).to_not include "encrypted_data_bag_secret"
        end

      end

    end

    describe 'when creating the Dockerfile' do
      subject(:dockerfile) do
        File.read("#{Chef::Config[:chef_repo_path]}/dockerfiles/docker/demo/Dockerfile")
      end

      context 'by default' do
        let(:argv) { %w[ docker/demo ] }

        before do
          reset_chef_config
          @knife.run
        end

        it 'should set the base_image name in a comment in the Dockerfile' do
          expect(dockerfile).to include '# BASE chef/ubuntu-12.04:latest'
        end

        it 'should remove the secure directory' do
          expect(dockerfile).to include 'RUN rm -rf /etc/chef/secure/*'
        end
      end

      context 'when include_credentials is specified' do
        let(:argv) { %w[ docker/demo --include-credentials ] }

        before do
          reset_chef_config
          @knife.run
        end

        it 'should not remove the secure directory' do
          expect(dockerfile).not_to include 'RUN rm -rf /etc/chef/secure/*'
        end
      end
    end

    describe "when no valid cookbook path is specified" do
      before(:each) do
        reset_chef_config
        Chef::Config[:cookbook_path] = '/tmp/nil/cookbooks'
      end

      let(:argv) { %W[
        docker/demo
        -r recipe[nginx]
        -z
        -b
      ]}

      it "should log an error and not copy cookbooks" do
        @knife.run
        expect(stdout).to include('log[Could not find a \'/tmp/nil/cookbooks\' directory in your chef-repo.] action write')
      end
    end

    describe "when copying cookbooks to temporary chef-repo" do
      context "and the chef config specifies multiple directories" do
        before do
          reset_chef_config
          Chef::Config[:cookbook_path] = ["#{fixtures_path}/cookbooks", "#{fixtures_path}/site-cookbooks"]
          @knife.run
        end

        let(:argv) { %W[
          docker/demo
          -r recipe[nginx],recipe[apt]
          -z
        ]}

        it "should copy cookbooks from both directories" do
          expect(stdout).to include("execute[cp -rf #{fixtures_path}/cookbooks/nginx #{tempdir}/dockerfiles/docker/demo/chef/cookbooks/] action run")
          expect(stdout).to include("execute[cp -rf #{fixtures_path}/site-cookbooks/apt #{tempdir}/dockerfiles/docker/demo/chef/cookbooks/] action run")
        end

        it "only copies cookbooks that exist in the run_list" do
          expect(stdout).not_to include("execute[cp -rf #{default_cookbook_path}/dummy #{Chef::Config[:chef_repo_path]}/dockerfiles/docker/demo/chef/cookbooks/] action run")
        end
      end
    end

    describe 'when running in local-mode' do
      before(:each) { reset_chef_config }

      let(:argv) { %W[
        docker/demo
        -r recipe[nginx]
        -z
      ]}

      let(:expected_container_file_relpaths) do
        %w[
          Dockerfile
          .dockerignore
          .gitignore
          chef/first-boot.json
          chef/zero.rb
          chef/.node_name
        ]
      end

      let(:expected_files) do
        expected_container_file_relpaths.map do |relpath|
          File.join(Chef::Config[:chef_repo_path], "dockerfiles", "docker/demo", relpath)
        end
      end

      it "creates a folder to manage the Dockerfile and Chef files" do
        @knife.run
        generated_files = Dir.glob("#{Chef::Config[:chef_repo_path]}/dockerfiles/docker/demo/**{,/*/**}/*", File::FNM_DOTMATCH)
        expected_files.each do |expected_file|
          expect(generated_files).to include(expected_file)
        end
      end
    end

    describe 'when running in server-mode' do
      before(:each) { reset_chef_config }

      let(:argv) { %W[
        docker/demo
        -r recipe[nginx]
      ]}

      let(:expected_container_file_relpaths) do
        %w[
          Dockerfile
          .dockerignore
          .gitignore
          chef/first-boot.json
          chef/client.rb
          chef/secure/validation.pem
          chef/secure/trusted_certs/chef_example_com.crt
          chef/.node_name
        ]
      end

      let(:expected_files) do
        expected_container_file_relpaths.map do |relpath|
          File.join(Chef::Config[:chef_repo_path], "dockerfiles", "docker/demo", relpath)
        end
      end

      it "creates a folder to manage the Dockerfile and Chef files" do
        @knife.run
        generated_files = Dir.glob("#{Chef::Config[:chef_repo_path]}/dockerfiles/docker/demo/**{,/*/**}/*", File::FNM_DOTMATCH)
        expected_files.each do |expected_file|
          expect(generated_files).to include(expected_file)
        end
      end
    end
  end

  describe "#download_and_tag_base_image" do
    before(:each) do
      reset_chef_config
      @knife.unstub(:download_and_tag_base_image)
    end

    let(:argv) { %w[ docker/demo ] }

    it "should run docker pull on the specified base image and tag it with the dockerfile name" do
      @knife.ui.should_receive(:info).exactly(3).times
      @knife.should_receive(:shell_out).with("docker pull chef/ubuntu-12.04:latest")
      @knife.should_receive(:shell_out).with("docker tag chef/ubuntu-12.04 docker/demo")
      @knife.run
    end
  end

  describe '#eval_current_system' do
    let(:argv) { %w[ docker/demo ] }

    context 'the context already exists' do
      before do
        reset_chef_config
        File.stub(:exist?).with(File.join(Chef::Config[:chef_repo_path], 'dockerfiles', 'docker', 'demo')).and_return(true)
      end

      it 'should warn the user if the context they are trying to create already exists' do
        @knife.should_receive(:show_usage)
        @knife.ui.should_receive(:fatal)
        lambda { @knife.run }.should raise_error(SystemExit)
      end
    end

    context 'the context already exists but the force flag was specified' do
      let(:argv) { %w[ docker/demo --force ] }

      before do
        reset_chef_config
        File.stub(:exist?).with(File.join(Chef::Config[:chef_repo_path], 'dockerfiles', 'docker', 'demo')).and_return(true)
        @knife.config[:dockerfiles_path] = File.join(Chef::Config[:chef_repo_path], 'dockerfiles')
      end

      it 'should delete that folder and proceed as normal' do
        FileUtils.should_receive(:rm_rf).with(File.join(Chef::Config[:chef_repo_path], 'dockerfiles', 'docker', 'demo'))
        @knife.read_and_validate_params
        @knife.set_config_defaults
        @knife.eval_current_system
      end
    end
  end
end
