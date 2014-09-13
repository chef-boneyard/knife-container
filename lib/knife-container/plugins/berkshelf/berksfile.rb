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

module KnifeContainer
  module Plugins
    class Berkshelf
      class Berksfile

        attr_accessor :force

        def initialize(path, config)
          validate!
        end

        def validate!
          # Does the Berksfile exist?
        end

        def upload
          self.install
          berks_upload_cmd = 'berks upload'
          berks_upload_cmd << ' --force' if config[:force_build]
          berks_upload_cmd << " --config=#{File.expand_path(config[:berks_config])}" if config[:berks_config]
          run_command(berks_upload_cmd)
        end

        def force_upload

        end

        def vendor(path)
          if File.exist?(File.join(chef_repo, 'cookbooks'))
            if config[:force_build]
              FileUtils.rm_rf(File.join(chef_repo, 'cookbooks'))
            else
              show_usage
              ui.fatal('A `cookbooks` directory already exists. You must either remove this directory from your dockerfile directory or use the `force` flag')
              exit 1
            end
          end

          self.install
          run_command("berks vendor #{path}")
        end

        def install
          run_command('berks install')
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
      end
    end
  end
end
