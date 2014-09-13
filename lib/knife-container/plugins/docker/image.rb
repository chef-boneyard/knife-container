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
  module Plugins
    class Docker
      class Image
        attr_reader :context
        attr_reader :name
        attr_reader :tag

        def initialize(args = {})
          @context = args['context'] || nil
          @name = args['name'] || @context.name || nil
          @tag = args['tag'] || 'latest'

          raise 'Image name or ID was not provided' if @name.nil?
        end

        def download
          ::Docker::Image.create(fromImage: @name, tag: @tag)
        end

        def tag(name=@name, tag)
          image = ::Docker::Image.get(name)
          image.tag(repo: name, tag: tag)
        end

        def build
          raise 'Build can only be used with a Docker Context' if @context.nil?
          img = ::Docker::Image.build_from_dir(dir) do |output|
            log = Chef::JSONCompat.new.parse(output)
            puts log['stream']
          end
        end

        def rebase
          raise 'Rebase can only be used with a Docker Context' if @context.nil?
          base_image = self.class.new(base_image_name)
          base_image = ::Docker::Image.create(fromImage: @context.base_image)
          current_image = ::Docker::Image.get(name: @name)
          current_image.remove
          base_image.tag(repo: @name, tag: @tag)
        end
      end
    end
  end
end
