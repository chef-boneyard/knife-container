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
require 'knife-container/plugins/docker'

describe KnifeContainer::Plugins::Docker do

  subject(:docker) { KnifeContainer::Plugins::Docker }

  describe '.parse_name' do
    it 'removes special characters from Docker Context name' do
      {
        'reg.example.com:1234/docker-demo' => 'reg_example_com_1234/docker-demo',
        'reg.example.com/docker-demo' => 'reg_example_com/docker-demo',
        'docker/demo' => 'docker/demo'
      }.each do |input, output|
        expect(docker.parse_name(input)).to eql(output)
      end
    end
  end
end
