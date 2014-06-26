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

require 'json'
require 'chef/knife'
require 'knife-container/command'
require 'chef/mixin/shell_out'

class Chef
  class Knife
    class ContainerDockerInit < Knife

      include KnifeContainer::Command

      banner "knife container docker init REPO/NAME [options]"

      option :base_image,
        :short => "-f [REPO/]IMAGE[:TAG]",
        :long => "--from [REPO/]IMAGE[:TAG]",
        :description => "The image to use for the FROM value in your Dockerfile",
        :proc => Proc.new { |f| Chef::Config[:knife][:docker_image] = f }

      option :run_list,
        :short => "-r RunlistItem,RunlistItem...,",
        :long => "--run-list RUN_LIST",
        :description => "Comma seperated list of roles/recipes to apply to your Docker image",
        :proc => Proc.new { |o| o.split(/[\s,]+/) }

      option :local_mode,
        :boolean => true,
        :short => "-z",
        :long => "--local-mode",
        :description => "Include and use a local chef repository to build the Docker image"

      option :generate_berksfile,
        :short => "-b",
        :long => "--berksfile",
        :description => "Generate a Berksfile based on the run_list provided",
        :boolean => true,
        :default => false

      option :validation_key,
        :long => "--validation-key PATH",
        :description => "The path to the validation key used by the client, typically a file named validation.pem"

      option :validation_client_name,
        :long => "--validation-client-name NAME",
        :description => "The name of the validation client, typically a client named chef-validator"

      option :trusted_certs_dir,
        :long => "--trusted-certs PATH",
        :description => "The path to the directory containing trusted certs"

      option :encrypted_data_bag_secret,
        :long => "--secret-file SECRET_FILE",
        :description => "A file containing the secret key to use to encrypt data bag item values"

      option :chef_server_url,
        :long => "--server-url URL",
        :description => "Chef Server URL"

      option :force,
        :long => "--force",
        :boolean => true,
        :desription => "Will overwrite existing Docker Contexts"

      option :cookbook_path,
        :long => "--cookbook-path PATH[:PATH]",
        :description => "A colon-seperated path to look for cookbooks",
        :proc => Proc.new { |o| o.split(':') }

      option :role_path,
        :long => "--role-path PATH[:PATH]",
        :description => "A colon-seperated path to look for roles",
        :proc => Proc.new { |o| o.split(':') }

      option :node_path,
        :long => "--node-path PATH[:PATH]",
        :description => "A colon-seperated path to look for node objects",
        :proc => Proc.new { |o| o.split(':') }

      option :environment_path,
        :long => "--environment-path PATH[:PATH]",
        :description => "A colon-seperated path to look for environments",
        :proc => Proc.new { |o| o.split(':') }

      option :dockerfiles_path,
        :short => "-d PATH",
        :long => "--dockerfiles-path PATH",
        :description => "Path to the directory where Docker contexts are kept",
        :proc => Proc.new { |d| Chef::Config[:knife][:dockerfiles_path] = d }

      def run
        read_and_validate_params
        set_config_defaults
        eval_current_system
        setup_context
        chef_runner.converge
        download_and_tag_base_image
      end

      def read_and_validate_params
        if @name_args.length < 1
          show_usage
          ui.fatal("You must specify a Dockerfile name")
          exit 1
        end

        if config[:generate_berksfile]
          begin
            require 'berkshelf'
          rescue LoadError
            show_usage
            ui.fatal("You must have the Berkshelf gem installed to use the Berksfile flag.")
            exit 1
          end
        end
      end

      def set_config_defaults
        %w(
          validation_key
          validation_client_name
          chef_server_url
          trusted_certs_dir
          encrypted_data_bag_secret
          cookbook_path
          node_path
          role_path
          environment_path
        ).each do |var|
          config[:"#{var}"] ||= Chef::Config[:"#{var}"]
        end

        config[:base_image] ||= "chef/ubuntu-12.04:latest"

        config[:run_list] ||= []

        Chef::Config[:knife][:dockerfiles_path] ||= File.join(Chef::Config[:chef_repo_path], "dockerfiles")
        config[:dockerfiles_path] = Chef::Config[:knife][:dockerfiles_path]
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
        generator_context.trusted_certs_dir = config[:trusted_certs_dir]
        generator_context.encrypted_data_bag_secret = config[:encrypted_data_bag_secret]
        generator_context.first_boot = first_boot_content
        generator_context.generate_berksfile = config[:generate_berksfile]
      end

      def recipe
        "docker_init"
      end

      def first_boot_content
        first_boot = {}
        first_boot['run_list'] = config[:run_list]
        JSON.pretty_generate(first_boot)
      end

      def chef_client_mode
        config[:local_mode] ? "zero" : "client"
      end

      def download_and_tag_base_image
        shell_out("docker pull #{config[:base_image]}")
        shell_out("docker tag #{config[:base_image]} #{@name_args[0]}")
      end

      def eval_current_system
        if File.exists?(File.join(config[:dockerfiles_path], @name_args[0]))
          if config[:force]
            FileUtils.rm_rf(File.join(config[:dockerfiles_path], @name_args[0]))
          else
            show_usage
            ui.fatal("The Docker Context you are trying to create already exists. Please use the --force flag if you would like to re-create this context.")
            exit 1
          end
        end
      end
    end
  end
end
