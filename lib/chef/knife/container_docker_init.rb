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

      attr_reader :docker_context

      banner 'knife container docker init REPOSITORY/IMAGE_NAME [options]'

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
        long:         '--generate-berksfile',
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

      option :data_bag_path,
        long:         '--data-bag-path PATH[:PATH]',
        description:  'A colon-seperated path to look for data bags',
        proc:         proc { |o| o.split(':') }

      option :dockerfiles_path,
        short:        '-d PATH',
        long:         '--dockerfiles-path PATH',
        description:  'Path to the directory where Docker contexts are kept'

      # Execute the plugin
      def run
        set_config_defaults

        begin
          validate
        rescue ValidationError => e
          show_usage
          ui.fatal(e.message)
          exit false
        end

        setup_context
        chef_runner.converge
        download_and_tag_base_image
        ui.info("\n#{ui.color("Context Created: #{docker_context_path}", :magenta)}")
      end

      # Set default configuration values
      #
      # @return [Hash] the config object that contains all the configuration values.
      def set_config_defaults
        %w(
          chef_server_url
          cookbook_path
          node_path
          role_path
          environment_path
          data_bag_path
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

        config
      end

      # Validate parameters and existing system state
      def validate
        raise ValidationError, 'You must specify a Dockerfile name' if @name_args.length < 1
        setup_and_verify_docker
        setup_and_verify_berkshelf if config[:generate_berksfile]
        verify_docker_context
      end

      # Run the Docker validation and create the Docker Context object
      def setup_and_verify_docker
        KnifeContainer::Plugins::Docker.validate!
        @docker_context = KnifeContainer::Plugins::Docker::Context.new(@name_args[0], config[:dockerfiles_path])
      end

      # Run the Berkshelf validation
      def setup_and_verify_berkshelf
        KnifeContainer::Plugins::Berkshelf.validate!
      end

      # Check to see if the Docker context already exists.
      def verify_docker_context
        if File.exist?(@docker_context.path)
          if config[:force]
            FileUtils.rm_rf(@docker_context.path)
          else
            raise ValidationError, 'The Docker Context you are trying to create already exists. ' \
              'Please use the --force flag if you would like to re-create this context.'
          end
        end
      end

      # Setup the generator context
      def setup_context
        generator_context.dockerfile_name = docker_context_name
        generator_context.dockerfiles_path = config[:dockerfiles_path]
        generator_context.base_image = config[:base_image]
        generator_context.chef_client_mode = chef_client_mode
        generator_context.run_list = config[:run_list]
        generator_context.cookbook_path = config[:cookbook_path]
        generator_context.role_path = config[:role_path]
        generator_context.node_path = config[:node_path]
        generator_context.data_bag_path = config[:data_bag_path]
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

      # The name of the recipe to use for the Chef Generator
      def recipe
        'docker_init'
      end

      # Generate and return the JSON object for our first-boot.json
      def first_boot_content
        first_boot = {}
        first_boot['run_list'] = config[:run_list]
        Chef::JSONCompat.to_json_pretty(first_boot)
      end

      # Return the mode in which to run: zero or client
      def chef_client_mode
        config[:local_mode] ? 'zero' : 'client'
      end

      # Return the path to the Docker Context
      def docker_context_path
        @docker_context.path
      end

      # Return the parsed name of the Docker Context with the special
      # characters removed.
      def docker_context_name
        @docker_context.parsed_name
      end

      # Download the base Docker image and tag it with the image name
      def download_and_tag_base_image
        ui.info("Downloading base image: #{config[:base_image]}. This process may take awhile...")
        name, tag = KnifeContainer::Plugins::Docker.parse_name(config[:base_image])
        image = KnifeContainer::Plugins::Docker::Image.new(name: name, tag: tag)
        image.download
        ui.info("Tagging base image #{name} as #{@docker_context.name}")
        image.tag('latest')
      end
    end
  end
end
