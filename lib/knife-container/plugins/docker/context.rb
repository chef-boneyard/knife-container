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
require 'knife-container/plugins/docker/image'
require 'knife-container/exceptions'

module KnifeContainer
  module Plugins
    class Docker
      class Context

        attr_accessor :name
        attr_accessor :dockerfiles_path

        # Create a new Dockerfile object to be manipulated
        #
        # @param path [String] The fully-qualified path to the directory where
        #   Docker Contexts are stored.
        # @param name [String] The name of the Docker Image this Dockerfile is
        #   responsible for maintaining.
        def initialize(name, dockerfiles_path)
          @name = name
          @dockerfiles_path = dockerfiles_path
          self.validate!
        end

        # Determines whether the Dockerfile name the user provides is valid.
        #
        # @return [TrueClass, FalseClass] whether the Dockerfile name is valid
        def validate!
          case
          when @name.match(/:([a-zA-Z0-9._\-]+)?$/) # Does it have a tag?
            raise ValidationError, 'Docker Context name may not have a tag'
          when @name.match(/^\w+:\/\//) # Does it include a protocol?
            raise ValidationError, 'Docker Context name may not start with a protocol'
          end
        end

        # The fully-qualified path to the docker context path
        #
        # @return [String] the full path
        def path
          File.join(@dockerfiles_path, parsed_name)
        end

        # Converts the Dockerfile name into something safe that can be used for a
        # context folder name.
        #
        # @return [String] the name with special characters replaced with '_'
        def parsed_name
          @name.gsub(/[\.\:]/, '_')
        end

        # The full path to the Dockerfile
        #
        # @return [String] the full path to the Dockerfile
        def dockerfile
          File.join(path, 'Dockerfile')
        end

        # Pull the BASE image name from the Dockerfile
        #
        # @return [String] The BASE image value
        def base_image
          File.open(self.dockerfile).each do |line|
            if line =~ /\# BASE (\S+)/
              base_image = line.match(/\# BASE (\S+)/)[1]
            end
          end
          base_image
        end
      end
    end
  end
end
