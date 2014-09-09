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
require 'knife-container/helpers'

describe KnifeContainer::Helpers do

  subject(:klass) {
    class DummyClass;include KnifeContainer::Helpers;end
    DummyClass.new
  }

  describe '.valid_dockerfile_name?' do
    let(:names) { Hash.new(
      'http://reg.example.com/image_name-test' => false,
      'http://reg.example.com:1234/image_name-test:tag' => false,
      'reg.example.com/image_name-test:tag' => false,
      'image_name-test:tag' => false,
      'image_name-test' => true
    )}

    it 'returns whether the name meets specified criteria' do
      names.each do |name, value|
        expect(klass.valid_dockerfile_name?(name)).to eq(value)
      end
    end
  end

  describe '.parse_dockerfile_name' do
    let(:input_values) { %w[
      reg.example.com:1234/image_name-test
      reg.example.com/image_name-test
      example.com:1234/image_name-test
      example.com/image_name-test
      example/image_name-test
      image_name-test
    ]}

    let(:output_values) { %w[
      reg_example_com_1234/image_name-test
      reg_example_com/image_name-test
      example_com_1234/image_name-test
      example_com/image_name-test
      example/image_name-test
      image_name-test
    ]}

    it 'replaces special characters in dockerfile names' do
      i = 0
      num = input_values.length

      while i < num do
        expect(klass.parse_dockerfile_name(input_values[i])).to eql(output_values[i])
        i += 1
      end
    end
  end
end
