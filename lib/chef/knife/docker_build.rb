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
require 'open3'

class Chef
  class Knife
    class DockerBuild < Knife

      include KnifeContainer::Command
      include Chef::Mixin::ShellOut

      banner "knife docker build REPO/NAME [options]"

      option :run_berks,
        :long => "--[no-]-berks",
        :description => "Run `berks vendor` for local-mode and `berks upload` for server-mode (if Berksfile exists)",
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
        setup_config_defaults
        setup_context
        run_berks
        build_image
      end


      def read_and_validate_params
        if @name_args.length < 1
          show_usage
          ui.fatal("You must specify a Dockerfile name")
          exit 1
        end

        if config[:run_berks]
          begin
            require 'berkshelf'
          rescue LoadError
            show_usage
            ui.fatal("You must have the Berkshelf gem installed to use the `berks` flag")
            exit 1
          else
            # other exception
          ensure
            # always executed
          end
        end
      end

      def setup_config_defaults
        Chef::Config[:knife][:dockerfiles_path] ||=File.join(Chef::Config[:chef_repo_path], "dockerfiles")
        config[:dockerfiles_path] = Chef::Config[:knife][:dockerfiles_path]
      end

      def setup_context
        generator_context.dockerfile_name = @name_args[0]
        generator_context.dockerfiles_path = config[:dockerfiles_path]
        generator_context.run_berks = config[:run_berks]
        generator_context.force_build = config[:force_build]
      end

      def run_berks
        if config[:run_berks]
          require 'berkshelf'
          require 'berkshelf/berksfile'
          dockerfile_dir = File.join(config[:dockerfiles_path], @name_args[0])
          berks = Berkshelf::Berksfile.from_file(File.join(dockerfile_dir, "Berksfile"))
          berks.install

          temp_chef_repo = File.join(dockerfile_dir, "chef")

          if File.exists?(File.join(temp_chef_repo, "zero.rb"))
            if File.exists?(File.join(temp_chef_repo, "cookbooks")) && config[:force_build]
              FileUtils.rm_rf(File.join(temp_chef_repo, "cookbooks"))
            end
            berks.vendor(File.join(temp_chef_repo, "cookbooks"))
          elsif File.exists?(File.join(temp_chef_repo, "client.rb"))
            if config[:force_build]
              berks.upload(force: true, freeze: true)
            else
              berks.upload
            end
          end
        end
      end


      def build_image
        Open3.popen2e(docker_build_command) do |stdin, stdout_err, wait_thr|
          while line = stdout_err.gets
            puts line
          end
          wait_thr.value
        end
      end

      def docker_build_command
        "docker build -t #{@name_args[0]} #{config[:dockerfiles_path]}/#{@name_args[0]}"
      end
    end 
  end
end
