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
require 'knife-container/plugins/berkshelf/berksfile'
require 'knife-container/exceptions'
require 'mkmf'

module KnifeContainer
  module Plugins
    class Berkshelf
      include KnifeContainer::Exceptions

      #
      # Validate that Berkshelf is properly installed and configured.
      #
      def self.validate!
        case
        when !installed?
          raise ValidationError, 'You must have Berkshelf installed to use the Berkshelf flag.'
        end
      end

      #
      # Determines whether Berkshelf is installed
      #
      # @return [TrueClass, FalseClass]
      #
      def self.installed?
        ! ::MakeMakefile.find_executable('berks').nil?
      end
    end
  end
end
