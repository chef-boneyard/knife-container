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
Chef::Knife::ContainerDockerInit.load_deps

describe Chef::Knife::ContainerDockerInit do

  let(:stdout_io) { StringIO.new }
  let(:stderr_io) { StringIO.new }

  def stdout
    stdout_io.string
  end

  def generator_context
    KnifeContainer::Generator.context
  end

  let(:default_cookbook_path) do
    File.expand_path('cookbooks', fixtures_path)
  end

  let(:reset_chef_config) do
    Chef::Config.reset
    Chef::Config[:chef_repo_path] = tempdir
    Chef::Config[:cookbook_path] = File.join(fixtures_path, 'cookbooks')
    Chef::Config[:chef_server_url] = "http://localhost:4000"
    Chef::Config[:validation_key] = File.join(fixtures_path, '.chef','validator.pem')
    Chef::Config[:trusted_certs_dir] = File.join(fixtures_path,'.chef', 'trusted_certs')
    Chef::Config[:validation_client_name] = 'masterchef'
    Chef::Config[:encrypted_data_bag_secret] = File.join(fixtures_path, '.chef', 'encrypted_data_bag_secret')
  end

  subject(:knife) do
    Chef::Knife::ContainerDockerInit.new(argv).tap do |c|
      allow(c).to receive(:output).and_return(true)
      allow(c.ui).to receive(:stdout).and_return(stdout_io)
      allow(c.chef_runner).to receive(:stdout).and_return(stdout_io)
    end
  end

  let(:argv) { %w[ docker/demo ] }
  let(:dockercontext_path) { "#{Chef::Config[:knife][:dockerfiles_path]}/docker/demo" }

  it 'initializes a new docker context' do
    allow(knife).to receive(:docker_context_path).and_return(dockercontext_path)
    expect(knife).to receive(:validate!)
    expect(knife).to receive(:setup_context)
    expect(knife.chef_runner).to receive(:converge)
    expect(knife).to receive(:download_and_tag_base_image)
    expect(knife.ui).to receive(:info)
    knife.run
  end

  describe 'when argv is empty' do
    let(:argv) { %W[] }

    it 'throws an error and prints a message' do
      lambda do
        expect(knife).to receive(:error_out)
        knife.run
      end
    end
  end

  describe 'when establishing configuration' do
    before(:each) do
      reset_chef_config
      allow(knife).to receive(:validate!) # skip validation
      allow(knife.chef_runner).to receive(:converge) # skip converge
      allow(knife).to receive(:download_and_tag_base_image) # skip image DL
      allow(knife.ui).to receive(:info) # skip printing the output
    end

    subject(:config) { knife.config }

    describe 'when no cli overrides have been specified' do
      it 'sets values to Chef::Config default values' do
        knife.run
        expect(config[:base_image]).to eql('chef/ubuntu-12.04:latest')
        expect(config[:dockerfiles_path]).to eql(File.join(tempdir, 'dockerfiles'))
        expect(config[:berksfile_source]).to eql('https://supermarket.getchef.com')
      end
    end

    describe 'when overrides are specified' do
      context 'using Chef::Config' do
        it 'respects that value' do
          Chef::Config[:knife][:base_docker_image] = 'docker/demo:11.12.8'
          Chef::Config[:knife][:berksfile_source] = 'https://mychefserver.com'
          knife.run
          expect(config[:base_image]).to eql('docker/demo:11.12.8')
          expect(config[:berksfile_source]).to eql('https://mychefserver.com')
        end
      end

      context 'with a tag' do
        let(:argv) { %w[ docker/demo -f docker/demo:11.12.8 ] }

        it 'respects that tag' do
          knife.run
          expect(config[:base_image]).to eql('docker/demo:11.12.8')
        end
      end

      context 'without a tag' do
        let(:argv) { %w[ docker/demo -f docker/demo ] }

        it 'should append the \'latest\' tag on the name' do
          knife.run
          expect(config[:base_image]).to eql("docker/demo:latest")
        end
      end
    end
  end

  #
  # Building out the context
  #
  describe 'when creating the context' do
    before do
      reset_chef_config
      allow(knife).to receive(:validate!) # skip validation
      allow(knife).to receive(:download_and_tag_base_image) # skip image DL
      allow(knife.ui).to receive(:info) # skip printing the output
    end

    context 'when -b is passed' do
      before { reset_chef_config }
      let(:argv) { %w[
        docker/demo
        -r role[demo],recipe[demo::recipe],recipe[nginx]
        -b
      ]}

      subject(:berksfile) do
        File.read("#{tempdir}/dockerfiles/docker/demo/Berksfile")
      end

      it 'generates a Berksfile based on the run_list' do
        knife.run
        expect(berksfile).to match(/cookbook "nginx"/)
        expect(berksfile).to match(/cookbook "demo"/)
      end
    end

    context 'when -z is passed' do
      let(:argv) { %w[ docker/demo -z ] }

      let(:expected_container_file_relpaths) do
        %w[
          Dockerfile
          .dockerignore
          chef/first-boot.json
          chef/zero.rb
          chef/.node_name
        ]
      end

      let(:expected_files) do
        expected_container_file_relpaths.map do |relpath|
          File.join(Chef::Config[:chef_repo_path], 'dockerfiles', 'docker/demo', relpath)
        end
      end

      it 'creates a folder to manage the Dockerfile and Chef files' do
        knife.run
        generated_files = Dir.glob("#{Chef::Config[:chef_repo_path]}/dockerfiles/docker/demo/**{,/*/**}/*", File::FNM_DOTMATCH)
        expected_files.each do |expected_file|
          expect(generated_files).to include(expected_file)
        end
      end

      it 'creates config with local-mode specific values' do
        knife.run
        config_file = File.read("#{tempdir}/dockerfiles/docker/demo/chef/zero.rb")
        expect(config_file).to include "require 'chef-init'"
        expect(config_file).to include 'node_name', 'ChefInit.node_name'
        expect(config_file).to include 'ssl_verify_mode', ':verify_peer'
        expect(config_file).to include 'cookbook_path', '["/etc/chef/cookbooks"]'
        expect(config_file).to include 'encrypted_data_bag_secret', '/etc/chef/secure/encrypted_data_bag_secret'
      end
    end

    describe 'when copying cookbooks to temporary chef-repo' do
      let(:argv) { %W[docker/demo -r recipe[nginx],recipe[apt] -z ]}
      before do
        Chef::Config[:cookbook_path] = [
          "#{fixtures_path}/cookbooks",
          "#{fixtures_path}/site-cookbooks"
        ]
        knife.run
      end

      it 'copies from both directories' do
        expect(stdout).to include("execute[cp -rf #{fixtures_path}/cookbooks/nginx #{tempdir}/dockerfiles/docker/demo/chef/cookbooks/] action run")
        expect(stdout).to include("execute[cp -rf #{fixtures_path}/site-cookbooks/apt #{tempdir}/dockerfiles/docker/demo/chef/cookbooks/] action run")
      end

      it 'copies only those that exist in the run_list' do
        expect(stdout).not_to include("execute[cp -rf  #{default_cookbook_path}/dummy  #{Chef::Config[:chef_repo_path]}/dockerfiles/docker/demo/chef/cookbooks/] action run")
      end
    end

    describe 'when invalid cookbook path is specified' do
      let(:argv) { %W[ docker/demo -r recipe[nginx] -z]}

      it 'logs an error and does not copy cookbooks' do
        Chef::Config[:cookbook_path] = '/tmp/nil/cookbooks'
        knife.run
        expect(stdout).to include('log[Could not find a \'/tmp/nil/cookbooks\' directory in your chef-repo.] action write')
      end
    end

    describe 'when creating chef/client.rb' do
      subject(:config_file) do
        File.read("#{tempdir}/dockerfiles/docker/demo/chef/client.rb")
      end

      it 'fills it server specific configuration' do
        knife.run
        expect(config_file).to match(/require 'chef-init'/)
        expect(config_file).to include 'node_name', 'ChefInit.node_name'
        expect(config_file).to include 'ssl_verify_mode', ':verify_peer'
        expect(config_file).to include 'chef_server_url', 'http://localhost:4000'
        expect(config_file).to include 'validation_key', '/etc/chef/secure/validation.pem'
        expect(config_file).to include 'client_key', '/etc/chef/secure/client.pem'
        expect(config_file).to include 'trusted_certs_dir', '/etc/chef/secure/trusted_certs'
        expect(config_file).to include 'validation_client_name', 'masterchef'
        expect(config_file).to include 'encrypted_data_bag_secret', '/etc/chef/secure/encrypted_data_bag_secret'
      end

      context 'and the encrypted_data_bag_secret is not specified' do
        it 'does not add encrypted_data_bag_secret value to config' do
          Chef::Config[:encrypted_data_bag_secret] = nil
          knife.run
          expect(config_file).to_not include 'encrypted_data_bag_secret'
        end
      end
    end

    describe 'when creating the Dockerfile' do
      let(:argv) { %w[ docker/demo --include-credentials ] }
      subject(:dockerfile) do
        File.read("#{Chef::Config[:chef_repo_path]}/dockerfiles/docker/demo/Dockerfile")
      end

      before { knife.run }

      it 'sets the base_image name in a comment in the Dockerfile' do
        expect(dockerfile).to include '# BASE chef/ubuntu-12.04:latest'
      end

      it 'does not remove the secure directory' do
        expect(dockerfile).to include 'RUN chef-init --bootstrap --no-remove-secure'
      end
    end

    let(:expected_container_file_relpaths) do
      %w[
        Dockerfile
        .dockerignore
        chef/first-boot.json
        chef/client.rb
        chef/secure/validation.pem
        chef/secure/trusted_certs/chef_example_com.crt
        chef/.node_name
      ]
    end

    let(:expected_files) do
      expected_container_file_relpaths.map do |relpath|
        ::File.join(Chef::Config[:chef_repo_path], 'dockerfiles', 'docker/demo', relpath)
      end
    end

    it 'creates a folder to manage the Dockerfile and Chef files' do
      knife.run
      generated_files = Dir.glob("#{Chef::Config[:chef_repo_path]}/dockerfiles/docker/demo/**{,/*/**}/*", File::FNM_DOTMATCH)
      expected_files.each do |expected_file|
        expect(generated_files).to include(expected_file)
      end
    end
  end
end
