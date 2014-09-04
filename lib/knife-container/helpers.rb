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
require 'knife-container/helpers/berkshelf'
require 'knife-container/helpers/docker'

module KnifeContainer
  module Helpers
    include KnifeContainer::Helpers::Berkshelf
    include KnifeContainer::Helpers::Docker

    #
    # Generates a short, but random UID for instances.
    #
    # @return [String]
    #
    def random_uid
      require 'securerandom' unless defined?(SecureRandom)
      SecureRandom.hex(3)
    end
  end
end
