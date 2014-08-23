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

module KnifeContainer
  module Helpers
    module Docker

      #
      # Determines whether the Docker image name the user gave is valid.
      #
      # @param name [String] the Dockerfile name
      #
      # @return [TrueClass, FalseClass] whether the Dockerfile name is valid
      #
      def valid_dockerfile_name?(name)
        case
        when name.match(/:([a-zA-Z0-9._\-]+)?$/) # Does it have a tag?
          false
        when name.match(/^\w+:\/\//) # Does it include a protocol?
          false
        else
          true
        end
      end

      #
      # Converts the dockerfile name into something safe
      #
      def encode_dockerfile_name(name)
        name.gsub(/[\.\:]/, '_')
      end

      #
      # Downloads the specified Docker Image from the Registry
      # TODO: print out status
      #
      def download_image(image_name)
        ui.info("Downloading #{image_name}")
        image = image_name.split(':')
        name = image[0]
        tag = image[1]
        if tag.nil?
          img = Docker::Image.create(:fromImage => name)
        else
          img = Docker::Image.create(:fromImage => name, :tag => tag)
        end
        img.id
      end


      #
      # Delete the specified image
      #
      def delete_image(image_name)
        ui.info("Deleting orphaned Docker image")
        image = Docker::Image.get(image_name)
        image.remove
      end

      #
      # Tag the specified Docker Image
      #
      def tag_image(image_id, image_name, tag='latest')
        image = Docker::Image.get(image_id)
        image.tag(:repo => image_name, :tag => tag)
      end

    end
  end
end
