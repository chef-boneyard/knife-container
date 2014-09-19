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

require 'chef/knife/container_docker_base'

class Chef
  class Knife
    #
    # `knife container docker rebase` rebases the existing docker image tag onto
    # a fresh download of the base image.
    #
    # === Examples
    #   knife container docker rebase myapp
    #
    class ContainerDockerRebase < Knife
      include Knife::ContainerDockerBase

      attr_reader :docker_context

      banner 'knife container docker rebase REPOSITORY/IMAGE_NAME [options]'

      #
      # Read and validate the parameters then rebase the Docker image
      #
      def run
        setup_config_defaults
        validate!
        rebase_docker_image
      end

      # Reads the input parameters and validates them.
      # Will exit if it encounters an error
      def validate!
        super(@name_args)
      rescue ValidationError => e
        show_usage
        ui.fatal(e.message)
        exit false
      end

      def rebase_docker_image
        @docker_context = KnifeContainer::Plugins::Docker::Context.new(@name_args[0], config[:dockerfiles_path])
        image = KnifeContainer::Plugins::Docker::Image.new(context: @docker_context)
        image.rebase
      end
    end
  end
end
