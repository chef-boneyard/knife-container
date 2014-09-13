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
require 'knife-container/plugins/docker/image'
require 'knife-container/plugins/docker/context'

module KnifeContainer
  module Plugins
    class Docker

      def self.validate!
        # Check to make sure we can communicate with the Docker API
        begin
          ::Docker.version
        rescue Excon::Errors::SocketError => e
          raise KnifeContainer::Exceptions::ValidationError, 'Could not connect to Docker API. Please make sure your Docker daemon '\
          'process is running. If you are using boot2docker, please ensure that '\
          'your VM is up and started.'
        end
      end
    end
  end
end
