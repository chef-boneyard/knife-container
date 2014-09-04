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
    class ContainerDockerRebuild < Knife
      include Knife::ContainerDockerBase

      banner 'knife container docker rebuild REPO/NAME [options]'

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
        redownload_docker_image
        run_build_image
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
        new_base_id = download_image(base_image_name)
        delete_image(@name_args[0])
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
        image = image_name.split(':')
        name = image[0]
        tag = image[1]
        if tag.nil?
          img = Docker::Image.create(:fromImage => name)
        else
          img = Docker::Image.create(:fromImage => name, :tag => tag)
        end
        img.id
      end

      #
      # Delete the specified image
      #
      def delete_image(image_name)
        ui.info("Deleting orphaned Docker Image")
        image = Docker::Image.get(image_name)
        image.remove
      end

      #
      # Tag the specified Docker Image
      #
      def tag_image(image_id, image_name, tag='latest')
        image = Docker::Image.get(image_id)
        image.tag(:repo => image_name, :tag => tag)
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
        File.join(docker_context, 'chef')
      end
    end
  end
end
