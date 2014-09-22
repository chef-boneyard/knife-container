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
require 'knife-container/exceptions'

module KnifeContainer
  module Plugins
    class Berkshelf
      #
      # This class is a KnifeContainer specific integration with a Berkshelf
      # Berksfile.
      #
      # @example Create a new Berksfile object
      #   my_berksfile = KnifeContainer::Plugins::Berkshelf::Berksfile('/path/to/Berksfile')
      #
      # @example Run `berks install` against a Berksfile
      #   my_berksfile = KnifeContainer::Plugins::Berkshelf::Berksfile('/path/to/Berksfile')
      #   myberksfile.install
      #
      # @example Run `berks upload` against a Berksfile
      #   my_berksfile = KnifeContainer::Plugins::Berkshelf::Berksfile('/path/to/Berksfile')
      #   myberksfile.upload
      #
      # @example Run `berks vendor` against a Berksfile
      #   my_berksfile = KnifeContainer::Plugins::Berkshelf::Berksfile('/path/to/Berksfile')
      #   myberksfile.vendor('/path/to/target_dir')
      #
      class Berksfile
        include KnifeContainer::Exceptions

        attr_accessor :berksfile
        attr_accessor :config
        attr_accessor :force

        def initialize(berksfile_path)
          @berksfile = berksfile_path
          @config = nil
          @force = false
          validate!
        end

        #
        # Run the `berks install`, then `berks upload` commands
        #
        def upload
          install
          run_command(upload_command)
        end

        #
        # Run the `berks install`, then `berks vendor` commands
        #
        def vendor(target_path)
          if File.exist?(target_path)
            if @force
              FileUtils.rm_rf(target_path)
            else
              # Does the target directory already exist?
              raise PluginError, '[Berkshelf] A `cookbooks` directory already ' \
              "exists at #{target_path}. You must either remove this directory from your dockerfile " \
              'directory or use the `force` flag.' if File.exist?(target_path) && !@force
            end
          end

          install
          run_command(vendor_command(target_path))
        end

        #
        # Run the `berks install` command
        #
        def install
          run_command('berks install')
        end

        private

        #
        # Validates that the Berkfile is properly configured. Raises an exception
        # if any errors are found.
        #
        def validate!
          # Does the Berksfile exist?
          raise ValidationError, 'There is no Berksfile specified at the path ' \
            'you specified.' unless File.exist?(@berksfile)
        end

        #
        # Return the command to use to run `berks vendor`
        #
        # @return [String]
        #
        def vendor_command(path)
          cmd = "berks vendor #{path}"
          cmd << ' --force' if @force
          cmd << " --config=#{File.expand_path(@config)}" if @config
          cmd
        end

        #
        # Return the command to use to run `berks upload`
        #
        # @return [String]
        #
        def upload_command
          cmd = 'berks upload'
          cmd << ' --force' if @force
          cmd << " --config=#{File.expand_path(@config)}" if @config
          cmd
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
