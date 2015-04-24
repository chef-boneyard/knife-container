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

require 'chef/knife/container_base'
require 'knife-container/plugins'
require 'knife-container/exceptions'

class Chef
  class Knife
    module ContainerDockerBase
      include Knife::ContainerBase
      include KnifeContainer::Exceptions

      # :nodoc:
      # Would prefer to do this in a rational way, but can't be done b/c of
      # Mixlib::CLI's design :(
      def self.included(includer)
        includer.class_eval do

          deps do
            require 'chef/json_compat'
          end

          option :dockerfiles_path,
            short:        '-d PATH',
            long:         '--dockerfiles-path PATH',
            description:  'Path to the directory where Docker contexts are kept.',
            proc:         proc { |p| Chef::Config[:knife][:dockerfiles_path] = p }

          option :force,
            long:         '--force',
            boolean:      true
        end
      end

      #
      # Reads the input parameters and validates them.
      #
      def validate!
        raise ValidationError, 'You must specify a Dockerfile name' if @name_args.length < 1
      end

      #
      # Returns the default Dockerfiles path
      #
      # @return [String]
      #
      def default_dockerfiles_path
        Chef::Config[:knife][:dockerfiles_path] || ::File.join(Chef::Config[:chef_repo_path], 'dockerfiles')
      end

      #
      # Returns the parsed name of the Docker Context
      #
      # @return [String]
      #
      def docker_context_name
        KnifeContainer::Plugins::Docker.parse_name(@name_args[0])
      end

      #
      # Returns the path to the Docker Context
      #
      # @return [String]
      #
      def docker_context_path
        ::File.join(config[:dockerfiles_path], docker_context_name)
      end

      #
      # Returns the path to the chef-repo inside the Docker Context
      #
      # @return [String]
      #
      def chef_repo
        ::File.join(docker_context_path, 'chef')
      end
    end
  end
end
