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
require 'chef/mixin/shell_out'

class Chef
  class Knife
    class ContainerDockerBuild < Knife
      include Chef::Mixin::ShellOut

      deps do
        # These two are needed for cleanup
        require 'chef/node'
        require 'chef/api_client'
      end

      banner "knife container docker build REPO/NAME [options]"

      option :run_berks,
        :long => "--[no-]berks",
        :description => "Run Berkshelf",
        :default => true,
        :boolean => true

      option :cleanup,
        :long => "--[no-]cleanup",
        :description => "Cleanup Chef and Docker artifacts",
        :default => true,
        :boolean => true

      option :force_build,
        :long => "--force",
        :description => "Force the Docker image build",
        :boolean => true

      option :dockerfiles_path,
        :short => "-d PATH",
        :long => "--dockerfiles-path PATH",
        :description => "Path to the directory where Docker contexts are kept",
        :proc => Proc.new { |d| Chef::Config[:knife][:dockerfiles_path] = d }

      #
      # Run the plugin
      #
      def run
        read_and_validate_params
        setup_config_defaults
        run_berks if config[:run_berks]
        build_image
        cleanup_artifacts if config[:cleanup]
      end

      #
      # Reads the input parameters and validates them.
      # Will exit if it encounters an error
      #
      def read_and_validate_params
        if @name_args.length < 1
          show_usage
          ui.fatal("You must specify a Dockerfile name")
          exit 1
        end

        # if berkshelf isn't installed, set run_berks to false
        if config[:run_berks]
          ver = shell_out("berks -v")
          config[:run_berks] = ver.stdout.match(/\d+\.\d+\.\d+/) ? true : false
        end
      end

      #
      # Set defaults for configuration values
      #
      def setup_config_defaults
        Chef::Config[:knife][:dockerfiles_path] ||= File.join(Chef::Config[:chef_repo_path], "dockerfiles")
        config[:dockerfiles_path] = Chef::Config[:knife][:dockerfiles_path]
      end

      #
      # Execute berkshelf locally
      #
      def run_berks
        if File.exists?(File.join(docker_context, "Berksfile"))
          if File.exists?(File.join(chef_repo, "zero.rb"))
            run_berks_vendor
          elsif File.exists?(File.join(chef_repo, "client.rb"))
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
        File.exists?(File.join(docker_context, "Berksfile"))
      end

      #
      # Installs all the cookbooks via Berkshelf
      #
      def run_berks_install
        run_command("berks install")
      end

      #
      # Vendors all the cookbooks into a directory inside the Docker Context
      #
      def run_berks_vendor
        if File.exists?(File.join(chef_repo, "cookbooks"))
          if config[:force_build]
            FileUtils.rm_rf(File.join(chef_repo, "cookbooks"))
          else
            show_usage
            ui.fatal("A `cookbooks` directory already exists. You must either remove this directory from your dockerfile directory or use the `force` flag")
            exit 1
          end
        end

        run_berks_install
        run_command("berks vendor #{chef_repo}")
      end

      #
      # Upload the cookbooks to the Chef Server
      #
      def run_berks_upload
        run_berks_install
        if config[:force_build]
          run_command("berks upload --force")
        else
          run_command("berks upload")
        end
      end

      #
      # Builds the Docker image
      #
      def build_image
        run_command(docker_build_command)
      end

      #
      # Cleanup build artifacts
      #
      def cleanup_artifacts
        unless config[:local_mode]
          destroy_item(Chef::Node, node_name, "node")
          destroy_item(Chef::ApiClient, node_name, "client")
        end
      end

      #
      # The command to use to build the Docker image
      #
      def docker_build_command
        "CHEF_NODE_NAME='#{node_name}' docker build -t #{@name_args[0]} #{docker_context}"
      end

      #
      # Run a shell command from the Docker Context directory
      #
      def run_command(cmd)
        shell_out(cmd, cwd: docker_context)
      end

      #
      # Returns the path to the Docker Context
      #
      # @return [String]
      #
      def docker_context
        File.join(config[:dockerfiles_path], @name_args[0])
      end

      #
      # Returns the path to the chef-repo inside the Docker Context
      #
      # @return [String]
      #
      def chef_repo
        File.join(docker_context, "chef")
      end

      #
      # Generates a node name for the Docker container
      #
      # @return [String]
      #
      def node_name
        return "#{@name_args[0]}-build"
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
