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

require 'knife-container/plugins/docker'
require 'knife-container/exceptions'

module KnifeContainer
  module Plugins
    class Docker
      #
      # This class is the representation of a Docker Context. It accepts two
      # parameters:
      #   1) Name of the Docker Context
      #   2) The directory to create the context in
      #
      # An instance of this class can be fed into Plugins::Docker::Image and
      # used to create an image based on this context.
      #
      class Context
        include KnifeContainer::Exceptions

        attr_accessor :name
        attr_accessor :dockerfiles_path

        #
        # Create a new Dockerfile object to be manipulated
        #
        # @param [String] name
        #   The name of the Docker Image this Dockerfile is responsible for maintaining.
        # @param [String] dockerfiles_path
        #   The fully-qualified path to the directory where Docker Contexts are stored.
        #
        def initialize(name, dockerfiles_path)
          @name = name
          @dockerfiles_path = dockerfiles_path
          validate!
        end

        #
        # Returns the fully-qualified path to the docker context path
        #
        # @return [String]
        #
        def path
          File.join(@dockerfiles_path, KnifeContainer::Plugins::Docker.parse_name(@name))
        end

        #
        # Returns the full path to the Dockerfile
        #
        # @return [String]
        #
        def dockerfile
          File.join(path, 'Dockerfile')
        end

        #
        # Returns the name of the Base image as calcuated from the Dockerfile
        #
        # @return [String]
        #
        def base_image
          base_image = nil
          File.open(dockerfile).each do |line|
            if line =~ /\# BASE (\S+)/
              base_image = line.match(/\# BASE (\S+)/)[1]
            end
          end
          raise PluginError, '[Docker] There is no base image specified in ' \
            "`#{dockerfile}`." if base_image.nil?
          base_image
        end

        private

        #
        # Validates the Docker Context object. Raises ValidationError if any
        # errors are found.
        #
        def validate!
          case
          when @name.match(/:([a-zA-Z0-9._\-]+)?$/) # Does it have a tag?
            raise ValidationError, 'Docker Context name may not have a tag'
          when @name.match(/^\w+:\/\//) # Does it include a protocol?
            raise ValidationError, 'Docker Context name may not start with a protocol'
          end
        end
      end
    end
  end
end
