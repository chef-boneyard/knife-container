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
    #
    # `knife container docker build` accepts in a name of a Docker Context and
    # builds it using the Docker API.
    #
    # @example Build a new Docker image based on the context 'myorg/myapp'
    #   knife container docker build myorg/myapp
    #
    class ContainerDockerBuild < Knife
      include Knife::ContainerDockerBase

      deps do
        # These two are needed for cleanup
        require 'chef/node'
        require 'chef/api_client'
      end

      banner 'knife container docker build REPOSITORY/IMAGE_NAME [options]'

      option :run_berks,
        long:         '--[no-]berks',
        description:  'Use Berkshelf to resolve Chef cookbook dependencies.',
        default:      true,
        boolean:      true

      option :berks_config,
        long:         '--berks-config CONFIG',
        description:  'Use the specified Berkshelf configuration file.'

      option :cleanup,
        long:         '--[no-]cleanup',
        description:  'Cleanup Chef and Docker artifacts after build completes.',
        default:      true,
        boolean:      true

      option :secure_dir,
        long:         '--secure-dir DIR',
        description:  'Path to local repository that contains Chef credentials.'

      option :tags,
        long:         '--tags TAG[,TAG]',
        description:  'Comma separated list of tags to apply to the image.',
        default:      ['latest'],
        proc:         proc { |o| o.split(/[\s,]+/) }

      #
      # Read and validate the parameters then build the Docker image
      #
      def run
        validate!
        backup_secure unless config[:secure_dir].nil?
        validate_and_run_berkshelf if config[:run_berks]
        validate_and_run_docker
        restore_secure unless config[:secure_dir].nil?
        cleanup_artifacts if config[:cleanup] && !config[:local_mode]
      end

      private

      #
      # Reads the input parameters and validates them.
      #
      def validate!
        super
        verify_config_file
        verify_secure_directory unless config[:secure_dir].nil?
      rescue ValidationError => e
        error_out(e.message)
      end

      #
      # Validates Berkshelf and runs it if configured to do so.
      #
      def validate_and_run_berkshelf
        berksfile_loc = ::File.join(docker_context_path, 'Berksfile')
        berksfile = KnifeContainer::Plugins::Berkshelf::Berksfile.new(berksfile_loc)
        if berksfile.exists?
          # Validate Berkshelf Installation
          begin
            KnifeContainer::Plugins::Berkshelf.validate!
          rescue ValidationError => e
            error_out(e.message)
          end

          # Configure Berkshelf
          berksfile.config = config[:berks_config]
          berksfile.force = config[:force]

          # Run Berkshelf
          case
          when ::File.exist?("#{chef_repo}/zero.rb")
            berksfile.vendor(::File.join(chef_repo, 'cookbooks'))
          when ::File.exist?("#{chef_repo}/client.rb")
            berksfile.upload
          end
        else
          ui.info('Berkshelf steps will be ignored because a Berksfile does ' \
            'exist in the Docker Context.')
        end
      end

      #
      # Validates Docker and runs it
      #
      def validate_and_run_docker
        # Validate the Docker installation
        begin
          KnifeContainer::Plugins::Docker.validate!
        rescue ValidationError => e
          error_out(e.message)
        end

        # Create the Docker Context
        docker_context = KnifeContainer::Plugins::Docker::Context.new(
          @name_args[0],
          config[:dockerfiles_path]
        )

        # Build the Docker Image
        image = KnifeContainer::Plugins::Docker::Image.new(context: docker_context)
        id = image.build

        # Tag the image
        config[:tags].each do |tag|
          image.tag(tag)
        end
      end

      #
      # Determine if we are running local or server mode
      #
      def verify_config_file
        case
        when ::File.exist?(File.join(chef_repo, 'zero.rb'))
          config[:local_mode] = true
        when ::File.exist?(File.join(chef_repo, 'client.rb'))
          config[:local_mode] = false
        else
          raise ValidationError, "Can not find a Chef configuration file in #{chef_repo}"
        end
      end

      #
      # Validate that there is a secure directory (/etc/chef/secure) that has
      # the necessary Chef credentials inside of it.
      #
      def verify_secure_directory
        case
        when !::File.directory?(config[:secure_dir])
          raise ValidationError, "SECURE_DIRECTORY: The directory #{config[:secure_dir]} does not exist."
        when !::File.exist?(File.join(config[:secure_dir], 'validation.pem')) &&
          !::File.exist?(File.join(config[:secure_dir], 'client.pem'))
          raise ValidationError, "SECURE_DIRECTORY: Can not find validation.pem or client.pem in #{config[:secure_dir]}."
        end
      end

      #
      # Move `secure` folder to `backup_secure` and copy the config[:secure_dir]
      # to the new `secure` folder.
      #
      # Note: The .dockerignore file has a line to ignore backup secure to it
      #       should not be included in the image.
      #
      def backup_secure
        ::FileUtils.mv("#{chef_repo}/secure","#{chef_repo}/secure_backup")
        ::FileUtils.cp_r(config[:secure_dir], "#{chef_repo}/secure")
      end

      #
      # Delete the temporary secure directory and restore the original from the
      # backup.
      #
      def restore_secure
        ::FileUtils.rm_rf("#{chef_repo}/secure")
        ::FileUtils.mv("#{chef_repo}secure_backup", "#{chef_repo}/secure")
      end

      #
      # Deletes the node object and the Chef API client from the Chef Server
      #
      def cleanup_artifacts
        destroy_item(Chef::Node, node_name, 'node')
        destroy_item(Chef::ApiClient, node_name, 'client')
      end

      #
      # Reads the node name for the Docker container from the .node_name
      # file that is generated by Docker::Init.
      #
      # @return [String]
      #
      def node_name
        ::File.read(File.join(chef_repo, '.node_name')).strip
      end

      #
      # Extracted from Chef::Knife.delete_object, because it has a
      # confirmation step built in... By not specifying the '--no-cleanup'
      # flag the user is already making their intent known.  It is not
      # necessary to make them confirm two more times.
      #
      def destroy_item(klass, name, type_name)
        begin
          object = klass.load(name)
          object.destroy
          ui.warn("Deleted #{type_name} #{name}")
        rescue Net::HTTPServerException
          ui.warn("Could not find a #{type_name} named #{name} to delete!")
        end
      end
    end
  end
end
