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

      option :dockerfiles_path,
        short:        '-d PATH',
        long:         '--dockerfiles-path PATH',
        description:  'Path to the directory where Docker contexts are kept',
        proc:         proc { |d| Chef::Config[:knife][:dockerfiles_path] = d }

      #
      # Run the plugin
      #
      def run
        validate
        setup_config_defaults
        run_berks if config[:run_berks]
        backup_secure unless config[:secure_dir].nil?
        build_image
        restore_secure unless config[:secure_dir].nil?
        cleanup_artifacts if config[:cleanup]
      end

      #
      # Reads the input parameters and validates them.
      # Will exit if it encounters an error
      #
      def validate
        if @name_args.length < 1
          show_usage
          ui.fatal('You must specify a Dockerfile name')
          exit 1
        end

        unless valid_dockerfile_name?(@name_args[0])
          show_usage
          ui.fatal('Your Dockerfile name cannot include a protocol or a tag.')
          exit 1
        end

        # if secure_dir doesn't exist or is missing files, exit
        if config[:secure_dir]
          case
          when !File.directory?(config[:secure_dir])
            ui.fatal("SECURE_DIRECTORY: The directory #{config[:secure_dir]}" \
              " does not exist.")
            exit 1
          when !File.exist?(File.join(config[:secure_dir], 'validation.pem')) &&
            !File.exist?(File.join(config[:secure_dir], 'client.pem'))
            ui.fatal("SECURE_DIRECTORY: Can not find validation.pem or client.pem" \
              " in #{config[:secure_dir]}.")
            exit 1
          end
        end

        # if berkshelf isn't installed, set run_berks to false
        unless berks_installed?
          ui.warn('The berks executable could not be found. Resolving the Berksfile will be skipped.')
          config[:run_berks] = false
        end

        if config[:berks_config]
          unless File.exist?(config[:berks_config])
            ui.fatal("No Berksfile configuration found at #{config[:berks_config]}")
            exit 1
          end
        end
      end

      #
      # Set defaults for configuration values
      #
      def setup_config_defaults
        Chef::Config[:knife][:dockerfiles_path] ||= File.join(Chef::Config[:chef_repo_path], 'dockerfiles')
        config[:dockerfiles_path] = Chef::Config[:knife][:dockerfiles_path]

        # Determine if we are running local or server mode
        case
        when File.exist?(File.join(config[:dockerfiles_path], @name_args[0], 'chef', 'zero.rb'))
          config[:local_mode] = true
        when File.exist?(File.join(config[:dockerfiles_path], @name_args[0], 'chef', 'client.rb'))
          config[:local_mode] = false
        else
          show_usage
          ui.fatal("Can not find a Chef configuration file in #{config[:dockerfiles_path]}/#{@name_args[0]}/chef")
          exit 1
        end
      end

      #
      # Execute berkshelf locally
      #
      def run_berks
        if File.exist?(File.join(docker_context, 'Berksfile'))
          if File.exist?(File.join(chef_repo, 'zero.rb'))
            run_berks_vendor
          elsif File.exist?(File.join(chef_repo, 'client.rb'))
            run_berks_upload
          end
        end
      end

      #
      # Determines whether a Berksfile exists in the Docker context
      #
      # @returns [TrueClass, FalseClass]
      #
      def berksfile_exists?
        File.exist?(File.join(docker_context, 'Berksfile'))
      end


      #
      # Installs all the cookbooks via Berkshelf
      #
      def run_berks_install
        run_command('berks install')
      end

      #
      # Vendors all the cookbooks into a directory inside the Docker Context
      #
      def run_berks_vendor
        if File.exist?(File.join(chef_repo, 'cookbooks'))
          if config[:force_build]
            FileUtils.rm_rf(File.join(chef_repo, 'cookbooks'))
          else
            show_usage
            ui.fatal('A `cookbooks` directory already exists. You must either remove this directory from your dockerfile directory or use the `force` flag')
            exit 1
          end
        end

        run_berks_install
        run_command("berks vendor #{chef_repo}/cookbooks")
      end

      #
      # Upload the cookbooks to the Chef Server
      #
      def run_berks_upload
        run_berks_install
        berks_upload_cmd = 'berks upload'
        berks_upload_cmd << ' --force' if config[:force_build]
        berks_upload_cmd << " --config=#{File.expand_path(config[:berks_config])}" if config[:berks_config]
        run_command(berks_upload_cmd)
      end

      #
      # Builds the Docker image
      #
      def build_image
        run_command(docker_build_command)
      end

      #
      # Move `secure` folder to `backup_secure` and copy the config[:secure_dir]
      # to the new `secure` folder.
      #
      # Note: The .dockerignore file has a line to ignore backup secure to it
      #       should not be included in the image.
      #
      def backup_secure
        FileUtils.mv("#{docker_context}/chef/secure",
          "#{docker_context}/chef/secure_backup")
        FileUtils.cp_r(config[:secure_dir], "#{docker_context}/chef/secure")
      end

      #
      # Delete the temporary secure directory and restore the original from the
      # backup.
      #
      def restore_secure
        FileUtils.rm_rf("#{docker_context}/chef/secure")
        FileUtils.mv("#{docker_context}/chef/secure_backup",
          "#{docker_context}/chef/secure")
      end

      #
      # Cleanup build artifacts
      #
      def cleanup_artifacts
        unless config[:local_mode]
          destroy_item(Chef::Node, node_name, 'node')
          destroy_item(Chef::ApiClient, node_name, 'client')
        end
      end

      #
      # The command to use to build the Docker image
      #
      def docker_build_command
        "docker build -t #{dockerfile_name} #{docker_context}"
      end

      #
      # Run a shell command from the Docker Context directory
      #
      def run_command(cmd)
        Open3.popen2e(cmd, chdir: docker_context) do |stdin, stdout_err, wait_thr|
          while line = stdout_err.gets
            puts line
          end
          wait_thr.value.to_i
        end
      end

      #
      # Returns the path to the Docker Context
      #
      # @return [String]
      #
      def docker_context
        File.join(config[:dockerfiles_path], dockerfile_name)
      end

      #
      # Returns the encoded Dockerfile name
      #
      def dockerfile_name
        encoded_dockerfile_name(@name_args[0])
      end

      #
      # Returns the path to the chef-repo inside the Docker Context
      #
      # @return [String]
      #
      def chef_repo
        File.join(docker_context, 'chef')
      end

      #
      # Generates a node name for the Docker container
      #
      # @return [String]
      #
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
