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
require 'docker'

class Chef
  class Knife
    class ContainerDockerRebuild < Knife
      include Chef::Mixin::ShellOut

      banner "knife container docker rebuild REPO/NAME [options]"

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
        redownload_docker_image
        run_build_image
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
      end

      #
      # Set defaults for configuration values
      #
      def setup_config_defaults
        Chef::Config[:knife][:dockerfiles_path] ||= File.join(Chef::Config[:chef_repo_path], "dockerfiles")
        config[:dockerfiles_path] = Chef::Config[:knife][:dockerfiles_path]
      end

      #
      # Redownload the BASE Docker Image, retag the HEAD and cleanup
      #
      def redownload_docker_image
        base_image_name = parse_dockerfile_for_base
        delete_image_history(@name_args[0], base_image_name)
        new_base_id = download_image(base_image_name)
        tag_image(new_base_id, @name_args[0])
      end

      #
      # Pull the BASE image name from the Dockerfile
      #
      def parse_dockerfile_for_base
        base_image = Chef::Config[:knife][:docker_image] || 'chef/ubuntu-12.04:latest'
        dockerfile = "#{docker_context}/Dockerfile"
        File.open(dockerfile).each do |line|
          if line =~ /\# BASE (\S+)/
            base_image = line.match(/\# BASE (\S+)/)[1]
          end
        end
        ui.info("Rebuilding #{@name_args[0]} on top of #{base_image}")
        base_image
      end

      #
      # Downloads the specified Docker Image from the Registry
      # TODO: print out status
      #
      def download_image(image_name)
        ui.info("Downloading #{image_name} from Docker Hub")
        img = Docker::Image.create('fromImage' => image_name)
        img.id
      end

      #
      # Delete all the images between HEAD and BASE
      #
      def delete_image_history(head, old_base)
        ui.info("Deleting orphaned Docker Images")
        head_image = Docker::Image.get(head)
        old_base_image = Docker::Image.get(old_base)

        history = head_image.history
        i = 0

        # recursively delete the intermediate images until
        # we reach the old BASE image
        begin
          id = history[i]['Id']
          unless id == old_base_image.id
            status = Docker::Image.remove(id)
            status.each do |action, id|
              ui.debug("#{action} #{id}")
            end
          end
          i += 1
        end while history[i]['Id'] != old_base_image.id
      end

      #
      # Tag the specified Docker Image
      #
      def tag_image(image_id, image_name, tag='latest')
        image = Docker::Image.get(image_id)
        image.tag('repo' => image_name, 'tag' => tag)
      end

      #
      # Run Chef::Knife::ContainerDockerBuild
      #
      #   Note: @cli_arguments is a global var from Mixlib::CLI where argv is
      #   put when parse_options is run as part of super's init.
      #
      def run_build_image
        build = Chef::Knife::ContainerDockerBuild.new(@cli_arguments)
        build.run
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
    end
  end
end
