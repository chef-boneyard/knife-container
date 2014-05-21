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
require 'chef/knife/container/docker_init'

describe KnifeContainer::DockerInit do

  def generator_context
    KnifeContainer::Generator.context
  end

  let(:stdout_io) { StringIO.new }
  let(:stderr_io) { StringIO.new }

  before do
    KnifeContainer::Generator.reset
  end

  context "when executed in local mode" do
    before do
      reset_tempdir
    end

    let(:argv) { %W[
      docker/demo
      -f ubuntu:12.04
      -r recipe[nginx]
      -z
      --cookbook-path #{fixtures_path}/cookbooks
      --node-path #{fixtures_path}/nodes
      --environment-path #{fixtures_path}/environments
      --role-path #{fixtures_path}/roles
      -d #{tempdir}/dockerfiles
    ]}
    
    let(:expected_container_file_relpaths) do
      %w[
        Dockerfile
        chef/first-boot.json
        chef/zero.rb
        chef/cookbooks/dummy/metadata.rb
        chef/nodes/demo.json
        chef/environments/dev.json
        chef/roles/base.json
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
      expect(generator_context.chef_client_mode).to eq("zero")
      expect(generator_context.run_list).to eq(%w[recipe[nginx]])
      expect(generator_context.cookbook_path).to eq("#{fixtures_path}/cookbooks")
      expect(generator_context.role_path).to eq("#{fixtures_path}/roles")
      expect(generator_context.environment_path).to eq("#{fixtures_path}/environments")
      expect(generator_context.node_path).to eq("#{fixtures_path}/nodes")
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
