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
    class ContainerDockerBuild < Knife
      include Knife::ContainerDockerBase

      attr_reader :docker_context
      attr_reader :berksfile

      deps do
        # These two are needed for cleanup
        require 'chef/node'
        require 'chef/api_client'
      end

      banner 'knife container docker build REPO/NAME [options]'

      option :run_berks,
        long:         '--[no-]berks',
        description:  'Run Berkshelf',
        default:      true,
        boolean:      true

      option :berks_config,
        long:         '--berks-config CONFIG',
        description:  'Use the specified Berkshelf configuration'

      option :cleanup,
        long:         '--[no-]cleanup',
        description:  'Cleanup Chef and Docker artifacts',
        default:      true,
        boolean:      true

      option :secure_dir,
        long:         '--secure-dir DIR',
        description:  'Path to a local repository that contains Chef credentials.'

      option :force_build,
        long:         '--force',
        description:  'Force the Docker image build',
        boolean:      true

      option :tags,
        long:         '--tags TAG[,TAG]',
        description:  'Comma separated list of tags you wish to apply to the image.',
        default:      ['latest'],
        proc:         proc { |o| o.split(/[\s,]+/) }

      option :dockerfiles_path,
        short:        '-d PATH',
        long:         '--dockerfiles-path PATH',
        description:  'Path to the directory where Docker contexts are kept',
        proc:         proc { |d| Chef::Config[:knife][:dockerfiles_path] = d }


      # Execute the plugin
      def run
        setup_config_defaults

        begin
          validate
        rescue ValidationError => e
          show_usage
          ui.fatal(e.message)
          exit false
        end

        run_berks if config[:run_berks]
        backup_secure unless config[:secure_dir].nil?
        build_docker_image
        restore_secure unless config[:secure_dir].nil?
        cleanup_artifacts if config[:cleanup] && !config[:local_mode]
      end

      # Set defaults for configuration values.
      def setup_config_defaults
        Chef::Config[:knife][:dockerfiles_path] ||= File.join(Chef::Config[:chef_repo_path], 'dockerfiles')
        config[:dockerfiles_path] = Chef::Config[:knife][:dockerfiles_path]
      end

      # Reads the input parameters and validates them.
      # Will exit if it encounters an error
      def validate
        raise ValidationError, 'You must specify a Dockerfile name' if @name_args.length < 1
        setup_and_verify_docker
        setup_and_verify_berkshelf if config[:run_berks]
        verify_config_file
        verify_secure_directory unless config[:secure_dir].nil?
      end

      # Validate the Docker installation and create the Docker Context object
      def setup_and_verify_docker
        KnifeContainer::Plugins::Docker.validate!
        @docker_context = KnifeContainer::Plugins::Docker::Context.new(@name_args[0], config[:dockerfiles_path])
      end

      # Validate the Berkshelf installation and create the Berksfile object
      def setup_and_verify_berkshelf
        KnifeContainer::Plugins::Berkshelf.validate!
        @berksfile = KnifeContainer::Plugins::Berkshelf::Berksfile.new("#{@docker_context.path}/Berksfile", config[:berks_config])
        @berksfile.force = config[:force]
      end

      # Determine if we are running local or server mode
      def verify_config_file
        case
        when File.exist?(File.join(chef_repo, 'zero.rb'))
          config[:local_mode] = true
        when File.exist?(File.join(chef_repo, 'client.rb'))
          config[:local_mode] = false
        else
          raise ValidationError, "Can not find a Chef configuration file in #{chef_repo}"
        end
      end

      # if secure_dir doesn't exist or is missing files, exit
      def verify_secure_directory
        case
        when !File.directory?(config[:secure_dir])
          raise ValidationError, "SECURE_DIRECTORY: The directory #{config[:secure_dir]}" \
            ' does not exist.'
        when !File.exist?(File.join(config[:secure_dir], 'validation.pem')) &&
          !File.exist?(File.join(config[:secure_dir], 'client.pem'))
          raise ValidationError, 'SECURE_DIRECTORY: Can not find validation.pem or client.pem' \
            " in #{config[:secure_dir]}."
        end
      end

      # Execute Berkshelf on the local machine.
      #
      # When running in local mode, Berkshelf will run a berks install and then
      # vendor cookbooks into the cookbooks directory.
      #
      # When running in server mode, Berkshelf will run a berks install and then
      # upload the cookbooks to the configuration specified in the config.
      def run_berks
        case
        when File.exist?(File.join(chef_repo, 'zero.rb'))
          KnifeContainer::Plugins::Berkshelf.vendor(@berksfile, "#{chef_repo}/cookbooks")
        when File.exist?(File.join(chef_repo, 'client.rb'))
          KnifeContainer::Plugins::Berkshelf.upload(@berksfile)
        end
      end

      # Builds the Docker image
      def build_docker_image
        image = KnifeContainer::Plugins::Docker::Image.new(context: @docker_context)
        id = image.build

        config[:tags].each do |tag|
          image.tag(tag)
        end
      end

      # Move `secure` folder to `backup_secure` and copy the config[:secure_dir]
      # to the new `secure` folder.
      #
      # Note: The .dockerignore file has a line to ignore backup secure to it
      #       should not be included in the image.
      def backup_secure
        FileUtils.mv("#{chef_repo}/secure","#{chef_repo}/secure_backup")
        FileUtils.cp_r(config[:secure_dir], "#{chef_repo}/secure")
      end

      # Delete the temporary secure directory and restore the original from the
      # backup.
      def restore_secure
        FileUtils.rm_rf("#{chef_repo}/secure")
        FileUtils.mv("#{chef_repo}secure_backup", "#{chef_repo}/secure")
      end

      # Deletes the node object and the Chef API client from the Chef Server
      def cleanup_artifacts
        destroy_item(Chef::Node, node_name, 'node')
        destroy_item(Chef::ApiClient, node_name, 'client')
      end

      # Returns the path to the chef-repo inside the Docker Context
      #
      # @return [String]
      def chef_repo
        File.join(@docker_context.path, 'chef')
      end

      # Reads the node name for the Docker container from the .node_name
      # file that is generated by Docker::Init.
      #
      # @return [String]
      def node_name
        File.read(File.join(chef_repo, '.node_name')).strip
      end

      # Extracted from Chef::Knife.delete_object, because it has a
      # confirmation step built in... By not specifying the '--no-cleanup'
      # flag the user is already making their intent known.  It is not
      # necessary to make them confirm two more times.
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
