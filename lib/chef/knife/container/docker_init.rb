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

require 'chef/knife'
require 'knife-container/command'

module KnifeContainer
  class DockerInit < Command

    banner "knife docker init REPO/NAME [options]"

    option :base_image,
      :short => "-f BASE_IMAGE[:TAG]",
      :long => "--from BASE_IMAGE[:TAG]",
      :description => "The image to use for the FROM value in your Dockerfile.",
      :proc => Proc.new { |f| Chef::Config[:knife][:docker_image] = f },
      :default => "chef/ubuntu:12.04"

    option :run_list,
      :short => "-r RunlistItem,RunlistItem...,",
      :long => "--run-list RUN_LIST",
      :description => "Comma seperated list of roles/recipes to apply.",
      :default => [],
      :proc => Proc.new { |o| o.split(/[\s,]+/) }

    option :chef_client_mode, 
      :boolean => true,
      :short => "-z",
      :long => "--local-mode",
      :description => "Include and ues a local chef repository to build the Docker image."

    option :validation_key,
      :long => "--validation-key VALIDATION_KEY_PATH",
      :defaut => Chef::Config[:validation_key]

    option :validation_client_name,
      :long => "--validation-client-name VALIDATION_CLIENT_NAME",
      :default => Chef::Config[:validation_client_name]

    option :chef_server_url,
      :long => "--server-url CHEF_SERVER_URL",
      :description => "Chef Server URL",
      :default => Chef::Config[:chef_server_url]

    option :cookbook_path,
      :long => "--cookbook-path COOKBOOK_PATH",
      :default => Chef::Config[:cookbook_path]

    option :role_path,
      :long => "--role-path ROLE_PATH",
      :default => Chef::Config[:role_path]

    option :node_path,
      :long => "--node-path NODE_PATH",
      :default => Chef::Config[:node_path]

    option :environment_path,
      :long => "--environment-path ENVIRONMENT_PATH",
      :default => Chef::Config[:environment_path]

    option :dockerfiles_path,
      :short => "-d DOCKERFILES_PATH",
      :long => "--dockerfiles-path DOCKERFILES_PATH",
      :proc => Proc.new { |d| Chef::Config[:knife][:dockerfiles_path] = d },
      :default => File.join(Chef::Config[:chef_repo_path], "dockerfiles")

    
    def run
      read_and_validate_params
      setup_context
      chef_runner.converge
    end

    def read_and_validate_params
      if @name_args.length < 1
        ui.error("You must specify a Dockerfile name")
        show_usage
        1
      end
    end

    def setup_context
      generator_context.dockerfile_name = @name_args[0]
      generator_context.dockerfiles_path = config[:dockerfiles_path]
      generator_context.base_image = config[:base_image]
      generator_context.chef_client_mode = chef_client_mode
      generator_context.run_list = config[:run_list]
      generator_context.cookbook_path = config[:cookbook_path]
      generator_context.role_path = config[:role_path]
      generator_context.node_path = config[:node_path]
      generator_context.environment_path = config[:environment_path]
      generator_context.chef_server_url = config[:chef_server_url]
      generator_context.validation_key = config[:validation_key]
      generator_context.validation_client_name = config[:validation_client_name]
      generator_context.first_boot = first_boot_content
    end

    def recipe
      "docker_init"
    end

    def first_boot_content
      first_boot = {}
      first_boot['run_list'] = config[:run_list]
      first_boot
    end

    def chef_client_mode
      if config[:chef_client_mode]
        "zero"
      else
        "client"
      end
    end

  end
end
