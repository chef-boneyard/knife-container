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
require 'knife-container/command'
require 'chef/mixin/shell_out'

class Chef
  class Knife
    class DockerBuild < Knife

      include KnifeContainer::Command
      include Chef::Mixin::ShellOut

      banner "knife docker build REPO/NAME [options]"

      option :run_berks,
        :long => "--[no-]-berks",
        :description => "Run `berks vendor` for local-mode and `berks upload` for server-mode.",
        :default => true,
        :boolean => true

      option :force_build,
        :long => "--force",
        :default => false,
        :boolean => true

      option :dockerfiles_path,
        :short => "-d DOCKERFILES_PATH",
        :long => "--dockerfiles-path DOCKERFILES_PATH",
        :proc => Proc.new { |d| Chef::Config[:knife][:dockerfiles_path] = d },
        :default => File.join(Chef::Config[:chef_repo_path], "dockerfiles")

      def run
        read_and_validate_params
        setup_context
        chef_runner.converge
      end


      def read_and_validate_params
        if @name_args.length < 1
          ui.error("You must specify a Dockerfile name")
          show_usage
          exit 1
        end
      end

      def setup_context
        generator_context.dockerfile_name = @name_args[0]
        generator_context.dockerfiles_path = config[:dockerfiles_path]
        generator_context.run_berks = config[:run_berks]
        generator_context.force_build = config[:force_build]
      end

      def recipe
        "docker_build"
      end
    end 
  end
end
