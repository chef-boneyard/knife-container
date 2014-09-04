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

require 'chef/knife/container_docker_base'

class Chef
  class Knife
    class ContainerDockerInit < Knife
      include Knife::ContainerDockerBase


      banner "knife container docker init REPO/NAME [options]"

      option :base_image,
        short:        '-f [REPOSITORY/]IMAGE[:TAG]',
        long:         '--from [REPOSITORY/]IMAGE[:TAG]',
        description:  'The image to use as the base for your Docker image',
        proc:         proc { |f| Chef::Config[:knife][:docker_image] = f }

      option :run_list,
        short:        '-r RunlistItem,RunlistItem...,',
        long:         '--run-list RUN_LIST',
        description:  'Comma seperated list of roles/recipes to apply to your Docker image',
        proc:         proc { |o| o.split(/[\s,]+/) }

      option :local_mode,
        boolean:      true,
        short:        '-z',
        long:         '--local-mode',
        description:  'Include and use a local chef repository to build the Docker image'

      option :generate_berksfile,
        short:        '-b',
        long:         '--berksfile',
        description:  'Generate a Berksfile based on the run_list provided',
        boolean:      true,
        default:      false

      option :include_credentials,
        long:         '--include-credentials',
        description:  'Include secure credentials in your Docker image',
        boolean:      true,
        default:      false

      option :validation_key,
        long:         '--validation-key PATH',
        description:  'The path to the validation key used by the client, typically a file named validation.pem'

      option :validation_client_name,
        long:         '--validation-client-name NAME',
        description:  'The name of the validation client, typically a client named chef-validator'

      option :trusted_certs_dir,
        long:         '--trusted-certs PATH',
        description:  'The path to the directory containing trusted certs'

      option :encrypted_data_bag_secret,
        long:         '--secret-file SECRET_FILE',
        description:  'A file containing the secret key to use to encrypt data bag item values'

      option :chef_server_url,
        long:         '--server-url URL',
        description:  'Chef Server URL'

      option :force,
        long:         '--force',
        boolean:      true,
        description:  'Will overwrite existing Docker Contexts'

      option :cookbook_path,
        long:         '--cookbook-path PATH[:PATH]',
        description:  'A colon-seperated path to look for cookbooks',
        proc:         proc { |o| o.split(':') }

      option :role_path,
        long:         '--role-path PATH[:PATH]',
        description:  'A colon-seperated path to look for roles',
        proc:         proc { |o| o.split(':') }

      option :node_path,
        long:         '--node-path PATH[:PATH]',
        description:  'A colon-seperated path to look for node objects',
        proc:         proc { |o| o.split(':') }

      option :environment_path,
        long:         '--environment-path PATH[:PATH]',
        description:  'A colon-seperated path to look for environments',
        proc:         proc { |o| o.split(':') }

      option :dockerfiles_path,
        short:        '-d PATH',
        long:         '--dockerfiles-path PATH',
        description:  'Path to the directory where Docker contexts are kept'

      #
      # Run the plugin
      #
      def run
        read_and_validate_params
        set_config_defaults
        eval_current_system
        setup_context
        chef_runner.converge
        download_and_tag_base_image
        ui.info("\n#{ui.color("Context Created: #{config[:dockerfiles_path]}/#{@name_args[0]}", :magenta)}")
      end

      #
      # Read and validate the parameters
      #
      def read_and_validate_params
        if @name_args.length < 1
          show_usage
          ui.fatal("You must specify a Dockerfile name")
          exit 1
        end

        unless valid_dockerfile_name?(@name_args[0])
          show_usage
          ui.fatal("Your Dockerfile name cannot include a protocol or a tag.")
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

      #
      # Set default configuration values
      #   We do this here and not in the option syntax because the Chef::Config
      #   is not available to us at that point. It also gives us a space to set
      #   other defaults.
      #
      def set_config_defaults
        %w(
          chef_server_url
          cookbook_path
          node_path
          role_path
          environment_path
          validation_key
          validation_client_name
          trusted_certs_dir
          encrypted_data_bag_secret
        ).each do |var|
          config[:"#{var}"] ||= Chef::Config[:"#{var}"]
        end

        config[:base_image] ||= Chef::Config[:knife][:docker_image] || 'chef/ubuntu-12.04:latest'

        config[:berksfile_source] ||= Chef::Config[:knife][:berksfile_source] || 'https://supermarket.getchef.com'

        # if no tag is specified, use latest
        unless config[:base_image] =~ /[a-zA-Z0-9\/]+:[a-zA-Z0-9.\-]+/
          config[:base_image] = "#{config[:base_image]}:latest"
        end

        config[:run_list] ||= []

        config[:dockerfiles_path] ||= Chef::Config[:knife][:dockerfiles_path] || File.join(Chef::Config[:chef_repo_path], 'dockerfiles')
      end

      #
      # Setup the generator context
      #
      def setup_context
        generator_context.dockerfile_name = encoded_dockerfile_name(@name_args[0])
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
        generator_context.berksfile_source = config[:berksfile_source]
        generator_context.include_credentials = config[:include_credentials]
      end

      #
      # The name of the recipe to use
      #
      # @return [String]
      #
      def recipe
        "docker_init"
      end

      #
      # Generate the JSON object for our first-boot.json
      #
      # @return [String]
      #
      def first_boot_content
        first_boot = {}
        first_boot['run_list'] = config[:run_list]
        JSON.pretty_generate(first_boot)
      end

      #
      # Return the mode in which to run: zero or client
      #
      # @return [String]
      #
      def chef_client_mode
        config[:local_mode] ? "zero" : "client"
      end

      #
      # Download the base Docker image and tag it with the image name
      #
      def download_and_tag_base_image
        ui.info("Downloading base image: #{config[:base_image]}. This process may take awhile...")
        shell_out("docker pull #{config[:base_image]}")
        image_name = config[:base_image].split(':')[0]
        ui.info("Tagging base image #{image_name} as #{@name_args[0]}")
        shell_out("docker tag #{image_name} #{@name_args[0]}")
      end

      #
      # Run some evaluations on the system to make sure it is in the state we need.
      #
      def eval_current_system
        # Check to see if the Docker context already exists.
        if File.exist?(File.join(config[:dockerfiles_path], @name_args[0]))
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
