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
require 'docker'
require 'chef/json_compat'
require 'knife-container/exceptions'

module KnifeContainer
  module Plugins
    class Docker
      #
      # This class is a representation of a Docker Image. It is a wrapper around
      # the native Docker::Image API.
      #
      class Image
        include KnifeContainer::Exceptions

        attr_reader :context
        attr_reader :image_name
        attr_reader :image_tag

        #
        # @param [Hash] options
        #
        def initialize(options = {})
          if options[:context].nil?
            @image_name = options[:name]
          else
            @context = options[:context]
            @image_name = @context.name
          end
          @image_tag = options[:tag] || 'latest'

          validate!
        end

        #
        # Communicates with the Docker API to download our image. Returns the
        # Docker::Image object from the Docker API.
        #
        # @return [Docker::Image]
        #
        def download
          ::Docker::Image.create(fromImage: @image_name, tag: @image_tag)
        end

        #
        # Tags the image with the provided tag
        #
        # @param [String] tag
        #   The tag to apply to the image
        #
        def tag(tag)
          image = ::Docker::Image.get(@image_name)
          image.tag(repo: @image_name, tag: tag)
        end

        #
        # Builds our Docker image while printing the output from the Docker API
        #
        def build
          raise PluginError, '[Docker] The build command can only be used with a Docker Context' if @context.nil?
          img = ::Docker::Image.build_from_dir(@context.path) do |output|
            log = Chef::JSONCompat.from_json(output)
            puts log['stream']
          end
        end

        #
        # Rebases our Docker Image on a new/fresh base image
        #
        def rebase
          raise PluginError, '[Docker] The rebase command can only be used with a Docker Context' if @context.nil?

          # Create an Image object for the context's base image
          base_image = ::Docker::Image.create(fromImage: @context.base_image)

          # Grab our current image by name and delete it
          current_image = ::Docker::Image.get(@image_name)
          current_image.remove

          # Retag our base image with the name of our image
          base_image.tag(repo: @image_name, tag: @image_tag)
        end

        #
        # Validates the object.
        #
        def validate!
          case
          when @image_name.nil?
            raise ValidationError, 'Docker image name or ID was not provided.'
          end
        end
      end
    end
  end
end
