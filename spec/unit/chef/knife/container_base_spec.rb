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

require 'spec_helper'
require 'chef/knife/container_base'

class Chef
  class Knife
    class FakeCommand < Knife
      include Chef::Knife::ContainerBase
    end
  end
end

describe Chef::Knife::ContainerBase do
  let(:klass) { Chef::Knife::FakeCommand.new }

  describe 'error_out' do
    it 'prints system message and then exits' do
      expect(klass).to receive(:show_usage)
      expect(klass.ui).to receive(:fatal).with('DOOM')
      expect(klass).to receive(:exit).with(false)
      klass.error_out('DOOM')
    end
  end
end
