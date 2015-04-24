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
require 'knife-container/command'

class Chef
  class Knife
    #
    # `knife container docker init` creates a new Docker context on your local
    # workstation based on the parameters that you provide.
    #
    # @example Build a new Docker Context named 'myorg/myapp'
    #   knife container docker init myorg/myapp
    #
    class ContainerDockerInit < Knife
      include Knife::ContainerDockerBase
      include KnifeContainer::Command

      banner 'knife container docker init REPOSITORY/IMAGE_NAME [options]'

      option :base_image,
        short:        '-f [REPOSITORY/]IMAGE[:TAG]',
        long:         '--from [REPOSITORY/]IMAGE[:TAG]',
        description:  'The image to use as the base for your Docker image'

      option :run_list,
        short:        '-r RunlistItem,RunlistItem...,',
        long:         '--run-list RUN_LIST',
        description:  'Comma seperated list of roles/recipes to apply to your Docker image',
        proc:         proc { |o| o.split(/[\s,]+/) }

      option :local_mode,
        short:        '-z',
        long:         '--local-mode',
        description:  'Include and use a local chef repository to build the Docker image',
        boolean:      true

      # This option to is prevent a breaking change. The --berksfile option has
      # been deprecated.
      option :old_generate_berksfile,
        long:         '--berksfile',
        boolean:      true,
        default:      false,
        proc:         proc { |b|
          Chef::Log.warn '[DEPRECATED] --berksfile is deprecated. Use --generate-berksfile'
          b
        }

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

      option :berksfile_source,
        long:         '--berksfile-source URL',
        description:  'The source value for the Berksfile.',
        proc:         proc { |url| Chef::Config[:knife][:berksfile_source] = url }

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

      #
      # Read and validate the parameters then create the Docker Context
      #
      def run
        validate!
        reconfigure
        setup_context
        chef_runner.converge
        download_and_tag_base_image
        ui.info("\n#{ui.color("Context Created: #{docker_context_path}", :magenta)}")
      end

      #
      # Reconfigure the DockerInit configuration.
      #
      def reconfigure
        # Grab settings from knife.rb
        config[:dockerfiles_path]   ||= default_dockerfiles_path
        config[:base_image]         ||= default_base_image
        config[:berksfile_source]   ||= default_berksfile_source

        # Grab settings from Chef::Config
        %w(
          validation_key
          validation_client_name
          trusted_certs_dir
          encrypted_data_bag_secret
          chef_server_url
          cookbook_path
          role_path
          node_path
          environment_path
          data_bag_path
        ).each do |key|
          config[key.to_sym]        ||= Chef::Config[key.to_sym]
        end

        # Set runlist to empty
        config[:run_list]           ||= []

        # Support the deprecated `--berksfile` method
        config[:generate_berksfile] ||= config[:old_generate_berksfile]

        # Append 'latest' tag if a tag was omitted from the base image name
        config[:base_image] += ':latest' unless config[:base_image].match(/[A-Za-z0-9_\/.:-]+:[A-Za-z0-9_-]+/)
      end

      private

      #
      # Validate parameters and existing system state
      #
      def validate!
        super

        # Validate Docker and Berkshelf installations
        KnifeContainer::Plugins::Docker.validate!
        KnifeContainer::Plugins::Berkshelf.validate! if config[:generate_berksfile]

        # Show depreceation warning for knife[:docker_image]
        ui.warn('[DEPRECATED] knife[:docker_image] has been deprecated. Please use ' \
          'knife[:base_docker_image].') unless Chef::Config[:knife][:docker_image].nil?

        # Check to see if a docker context already exists
        if File.exist?(docker_context_path)
          if config[:force]
            FileUtils.rm_rf(docker_context_path)
          else
            raise ValidationError, 'The Docker Context you are trying to ' \
              'create already exists. Please use the --force flag if you ' \
              'would like to re-create this context.'
          end
        end
      rescue ValidationError => e
        error_out(e.message)
      end

      #
      # Setup the generator context
      #
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

      #
      # Returns the name of the recipe to use for the Chef Generator
      #
      # @return [String]
      #
      def recipe
        'docker_init'
      end

      #
      # Download the base Docker image and tag it with the image name
      #
      def download_and_tag_base_image
        ui.info("Downloading base image: #{config[:base_image]}. This process may take awhile...")
        name, tag = config[:base_image].split(':')
        image = KnifeContainer::Plugins::Docker::Image.new(name: name, tag: tag)
        image.download
        ui.info("Tagging base image #{name} as #{docker_context_name}")
        image.tag('latest')
      end

      #
      # Generate and return the JSON object for our first-boot.json
      #
      # @return [String]
      #
      def first_boot_content
        first_boot = {}
        first_boot['run_list'] = config[:run_list]
        Chef::JSONCompat.to_json_pretty(first_boot)
      end

      #
      # Return the mode in which to run: zero or client
      #
      # @return [String]
      #
      def chef_client_mode
        config[:local_mode] ? 'zero' : 'client'
      end

      #
      # Return the base Docker image to use
      #
      # @return [String]
      #
      def default_base_image
        Chef::Config[:knife][:docker_image] || Chef::Config[:knife][:base_docker_image] || 'chef/ubuntu-12.04:latest'
      end

      #
      # Return the default URL to use in the Berksfile
      #
      # @return [String]
      #
      def default_berksfile_source
        Chef::Config[:knife][:berksfile_source] || 'https://supermarket.getchef.com'
      end
    end
  end
end
