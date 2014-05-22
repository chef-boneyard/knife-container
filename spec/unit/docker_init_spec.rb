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

  def generator_context
    KnifeContainer::Generator.context
  end

  before do
    KnifeContainer::Generator.reset
  end

  describe 'read_and_validate_params' do
    it 'requires a dockerfile name be passed in'
    it 'checks to see if berkshelf is installed if using berkshelf functionality'
  end

  describe 'set_config_defaults' do
    context 'when no cli overrides have been specified' do
      it 'sets validation_key to Chef::Config value'
      it 'sets validation_client_name to Chef::Config value'
      it 'sets chef_server_url to Chef::Config value'
      it 'sets cookbook_path to Chef::Config value'
      it 'sets node_path to Chef::Config value'
      it 'sets role_path to Chef::Config value'
      it 'sets environment_path to Chef::Config value'
      it 'sets dockerfiles_path to Chef::Config[:dockerfiles_path]'
      
      context 'when Chef::Config[:dockerfiles_path] has not been set' do
        it 'sets dockerfiles_path to Chef::Config[:chef_repo_path]/dockerfiles'
      end
    end
  end

  describe 'setup_context' do
    context 'defaults only'
      it 'sets the default base_image to chef/ubuntu_12.04'
      it 'sets the runlist to an empty array'
      it 'sets localmode to false'

  end

  describe 'first_value' do
    it 'should return the first value of an array if an array is passed in'
    it 'should return the full string if a string is passed in'
  end

  describe 'first_boot_content' do
    it 'should add the run_list value' 
  end

  it "defaults to chef/ubuntu_12.04 for a docker base image"

  it "generates a Berksfile based on the run_list when -b is specified with no value"

  it "copies an existing Berksfile when a filepath is specified with the -b flag"

  context "when executed in local mode" do
    before do
      reset_tempdir
    end

    let(:argv) { %W[
      docker/demo
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
        File.join(tempdir, "dockerfiles", "docker/demo", relpath)
      end
    end

    subject(:docker_init) { described_class.new(argv) }

    it "configures the Generator context" do
      docker_init.read_and_validate_params
      docker_init.setup_context
      expect(generator_context.dockerfile_name).to eq("docker/demo")
      expect(generator_context.dockerfiles_path).to eq("#{tempdir}/dockerfiles")
      expect(generator_context.base_image).to eq("chef/ubuntu_12.04")
      expect(generator_context.chef_client_mode).to eq("zero")
      expect(generator_context.run_list).to eq(%w[recipe[nginx]])
      expect(generator_context.berksfile).to eq("#{fixtures_path}/Berksfile")
    end

    it "creates a folder to manage the Dockerfile and Chef files" do
      Dir.chdir(tempdir) do
        docker_init.chef_runner.stub(:stdout).and_return(stdout_io)
        docker_init.run
      end
      generated_files = Dir.glob("#{tempdir}/dockerfiles/docker/demo/**{,/*/**}/*", File::FNM_DOTMATCH)
      expected_files.each do |expected_file|
        expect(generated_files).to include(expected_file)
      end
    end
  end

  describe "executed in server mode" do
    before do
      reset_tempdir
    end

    let(:argv) { %W[
      docker/demo
      -f ubuntu:12.04
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
        File.join(tempdir, "dockerfiles", "docker/demo", relpath)
      end
    end
    
    subject(:docker_init) { described_class.new(argv) }

    it "configures the Generator context" do
      docker_init.read_and_validate_params
      docker_init.setup_context
      expect(generator_context.dockerfile_name).to eq("docker/demo")
      expect(generator_context.dockerfiles_path).to eq("#{tempdir}/dockerfiles")
      expect(generator_context.base_image).to eq("ubuntu:12.04")
      expect(generator_context.chef_client_mode).to eq("client")
      expect(generator_context.run_list).to eq(%w[recipe[nginx]])
      expect(generator_context.chef_server_url).to eq("http://localhost:4000")
      expect(generator_context.validation_client_name).to eq("masterchef")
      expect(generator_context.validation_key).to eq("#{fixtures_path}/.chef/validation.pem")
    end

    it "creates a folder to manage the Dockerfile and Chef files" do
      Dir.chdir(tempdir) do
        docker_init.chef_runner.stub(:stdout).and_return(stdout_io)
        docker_init.run
      end
      generated_files = Dir.glob("#{tempdir}/dockerfiles/docker/demo/**{,/*/**}/*", File::FNM_DOTMATCH)
      expected_files.each do |expected_file|
        expect(generated_files).to include(expected_file)
      end
    end
  end

end
