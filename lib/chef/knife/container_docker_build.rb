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
    class ContainerDockerBuild < Knife

      include KnifeContainer::Command
      include Chef::Mixin::ShellOut

      banner "knife container docker build REPO/NAME [options]"

      option :run_berks,
        :long => "--no-berks",
        :description => "Skip Berkshelf steps",
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

      def run
        read_and_validate_params
        setup_config_defaults
        run_berks if config[:run_berks]
        build_image
      end

      def read_and_validate_params
        if @name_args.length < 1
          ui.fatal("You must specify a Dockerfile name")
          show_usage
          exit 1
        end

        # Was --no-berks passed?
        if config[:run_berks].nil?
          
          # If it wasn't passed but berkshelf isn't installed, set false
          ver = shell_out("berks -v")
          config[:run_berks] = ver.stdout.match(/\d+\.\d+\.\d+/) ? true : false
        end
      end

      def setup_config_defaults
        Chef::Config[:knife][:dockerfiles_path] ||=File.join(Chef::Config[:chef_repo_path], "dockerfiles")
        config[:dockerfiles_path] = Chef::Config[:knife][:dockerfiles_path]
      end

      def run_berks
        if berksfile_exists?
          if File.exists?(File.join(chef_repo, "zero.rb"))
            run_berks_vendor
          elsif File.exists?(File.join(chef_repo, "client.rb"))
            run_berks_upload
          end
        end
      end

      def berksfile_exists?
        File.exists?(File.join(docker_context, "Berksfile"))
      end

      def run_berks_install
        run_command("berks install")
      end

      def run_berks_vendor
        if File.exists?(File.join(chef_repo, "cookbooks"))
          if config[:force_build]
            FileUtils.rm_rf(File.join(chef_repo, "cookbooks"))
          else
            ui.fatal("A `cookbooks` directory already exists. You must either remove this directory from your dockerfile directory or use the `force` flag")
            show_usage
            exit 1
          end
        end
        
        run_berks_install
        run_command("berks vendor #{chef_repo}")
      end

      def run_berks_upload
        run_berks_install
        if config[:force_build]
          run_command("berks upload --force")
        else
          run_command("berks upload")
        end
      end

      def build_image
        run_command(docker_build_command)
      end

      def docker_build_command
        "docker build -t #{@name_args[0]} #{docker_context}"
      end

      def run_command(cmd)
        shell_out(cmd, cwd: docker_context)
      end

      def docker_context
        File.join(config[:dockerfiles_path], @name_args[0])
      end

      def chef_repo
        File.join(docker_context, "chef")
      end
    end
  end
end
