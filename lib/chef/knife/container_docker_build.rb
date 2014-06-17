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

        if config[:run_berks].nil?
          config[:run_berks] = true
        end

        if config[:run_berks]
          begin
            require 'berkshelf'
            require 'berkshelf/berksfile'
          rescue LoadError
            ui.fatal("You must have the Berkshelf gem installed to use the `berks` flag")
            show_usage
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

      def run_berks
        dockerfile_dir = File.join(config[:dockerfiles_path], @name_args[0])
        berks = Berkshelf::Berksfile.from_file(File.join(dockerfile_dir, "Berksfile"))
        berks.install

        temp_chef_repo = File.join(dockerfile_dir, "chef")

        if File.exists?(File.join(temp_chef_repo, "zero.rb"))
          run_berks_vendor(berks, temp_chef_repo)
        elsif File.exists?(File.join(temp_chef_repo, "client.rb"))
          run_berks_upload(berks, temp_chef_repo)
        end
      end

      def run_berks_vendor(berks, temp_chef_repo)
        if File.exists?(File.join(temp_chef_repo, "cookbooks")) 
          if config[:force_build]
            FileUtils.rm_rf(File.join(temp_chef_repo, "cookbooks"))
          else
            ui.fatal("A `cookbooks` directory already exists. You must either remove this directory from your dockerfile directory or use the `force` flag")
            show_usage
            exit 1
          end
        end

        berks.vendor(File.join(temp_chef_repo, "cookbooks"))
      end

      def run_berks_upload(berks, temp_chef_repo)
        if config[:force_build]
          berks.upload(force: true, freeze: true)
        else
          berks.upload
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
