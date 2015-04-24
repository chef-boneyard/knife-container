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
require 'knife-container/plugins/docker/context'

describe KnifeContainer::Plugins::Docker::Context do

  subject(:context) { KnifeContainer::Plugins::Docker::Context }

  describe '#new' do
    it 'accepts and validates two values: name and dockerfiles_path' do
      expect{ context.new }.to raise_error
      my_context = context.new('docker/demo', '/tmp')
      expect(my_context.name).to eql('docker/demo')
      expect(my_context.dockerfiles_path).to eql('/tmp')
    end

    describe 'when validation fails' do
      it 'raises a ValidationError' do
        # bad name
        expect{ context.new('docker/demo:latest', '/tmp') }.to raise_error KnifeContainer::Exceptions::ValidationError
        # includes protocol
        expect{ context.new('http://registry.example.com/docker/demo', '/tmp') }.to raise_error KnifeContainer::Exceptions::ValidationError
      end
    end
  end

  describe '#path' do
    it 'returns the parsed path to the Docker Context' do
      my_context = context.new('registry.example.com:400/docker/demo', '/tmp')
      expect(my_context.path).to eql('/tmp/registry_example_com_400/docker/demo')
    end
  end

  describe '#dockerfile' do
    it 'returns the path to the Dockerfile' do
      my_context = context.new('docker/demo', '/tmp')
      expect(my_context.dockerfile).to eql('/tmp/docker/demo/Dockerfile')
    end
  end

  describe '#base_image' do
    it 'returns the name of the base image for the Docker Context' do
      my_context = context.new('docker/demo', '/tmp')
      allow(my_context).to receive(:dockerfile).and_return("#{fixtures_path}/Dockerfile")
      expect(my_context.base_image).to eql('chef/ubuntu-12.04:latest')
    end
  end
end
