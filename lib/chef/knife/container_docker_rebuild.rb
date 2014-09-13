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

      attr_reader :docker_context

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


      # Run the plugin
      def run
        setup_config_defaults

        begin
          validate
        rescue ValidationError => e
          show_usage
          ui.fatal(e.message)
          exit false
        end
        
        rebase_docker_image
        run_build_image
      end

      # Set defaults for configuration values
      def setup_config_defaults
        Chef::Config[:knife][:dockerfiles_path] ||= File.join(Chef::Config[:chef_repo_path], "dockerfiles")
        config[:dockerfiles_path] = Chef::Config[:knife][:dockerfiles_path]
      end

      # Reads the input parameters and validates them.
      # Will exit if it encounters an error
      def validate
        raise ValidationError, 'You must specify a Dockerfile name' if @name_args.length < 1
        @docker_context = KnifeContainer::Plugins::Docker::Context.new(@name_args[0], config[:dockerfiles_path])
      end

      def rebase_docker_image
        image = KnifeContainer::Plugins::Docker::Image.new(context: @docker_context)
        image.rebase
      end

      def run_build_image
        build = Chef::Knife::ContainerDockerBuild.new(@cli_arguments)
        build.run
      end
    end
  end
end
