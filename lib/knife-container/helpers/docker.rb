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
      def parse_dockerfile_name(name)
        name.gsub(/[\.\:]/, '_')
      end

      #
      # Downloads the specified Docker Image from the Registry
      # TODO: print out status
      #
      def download_image(image_name)
        ui.info("Downloading #{image_name}")
        name, tag = image_name.split(':')
        if tag.nil?
          img = ::Docker::Image.create(:fromImage => name)
        else
          img = ::Docker::Image.create(:fromImage => name, :tag => tag)
        end
        img.id
      rescue Excon::Errors::SocketError => e
        ui.fatal(connection_error)
        exit 1
      end

      #
      # Build Docker Image
      #
      def build_image(dir)
        ui.info("Building image based on Dockerfile in #{dir}")
        img = ::Docker::Image.build_from_dir(dir) do |output|
          log = Chef::JSONCompat.new.parse(output)
          puts log['stream']
        end
      rescue Excon::Errors::SocketError => e
        ui.fatal(connection_error)
        exit 1
      end

      #
      # Build Docker Image
      #
      def build_image

      end


      #
      # Delete the specified image
      #
      def delete_image(image_name)
        ui.info("Deleting Docker image #{image_name}")
        image = ::Docker::Image.get(image_name)
        image.remove
      rescue Excon::Errors::SocketError => e
        ui.fatal(connection_error)
        exit 1
      end

      #
      # Tag the specified Docker Image
      #
      def tag_image(image_id, image_name, tag='latest')
        ui.info("Add tag #{image_name}:#{tag} to #{image_id}")
        image = ::Docker::Image.get(image_id)
        image.tag(:repo => image_name, :tag => tag)
      rescue Excon::Errors::SocketError => e
        ui.fatal(connection_error)
        exit 1
      end

      def connection_error
        'Could not connect to Docker API. Please make sure your Docker daemon '\
        'process is running. If you are using boot2docker, please ensure that '\
        'your VM is up and started.'
      end

    end
  end
end
