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
require 'knife-container/plugins/docker/image'

describe KnifeContainer::Plugins::Docker::Image do

  subject(:image) { KnifeContainer::Plugins::Docker::Image }
  let(:context) { double('KnifeContainer::Plugins::Docker::Context', name: 'docker/demo', path: '/tmp/docker/demo', base_image: 'chef/base_image') }

  describe '#new' do
    it 'accepts a docker name (with optional tag)' do
      my_image = image.new(name: 'docker/demo', tag: 'mytag')
      expect(my_image.image_name).to eql('docker/demo')
      expect(my_image.image_tag).to eql('mytag')
      my_image2 = image.new(name: 'docker/demo2')
      expect(my_image2.image_name).to eql('docker/demo2')
      expect(my_image2.image_tag).to eql('latest')
    end

    it 'accepts a docker context (with optional tag)' do
      my_image = image.new(context: context)
      expect(my_image.context).to eql(context)
      expect(my_image.image_name).to eql('docker/demo')
      expect(my_image.image_tag).to eql('latest')
      my_image2 = image.new(context: context, tag: 'mytag')
      expect(my_image2.context).to eql(context)
      expect(my_image2.image_name).to eql('docker/demo')
      expect(my_image2.image_tag).to eql('mytag')
    end

    it 'raises an error if neither name nor context are provided' do
      expect{ image.new }.to raise_error
      expect{ image.new(tag: 'mytag') }.to raise_error KnifeContainer::Exceptions::ValidationError
    end
  end

  describe '#download' do
    it 'downloads the Docker Image' do
      expect(::Docker::Image).to receive(:create).with(fromImage: 'docker/demo-name', tag: 'mytag')
      expect(::Docker::Image).to receive(:create).with(fromImage: 'docker/demo', tag: 'latest')
      my_image = image.new(name: 'docker/demo-name', tag: 'mytag')
      my_image.download
      my_image2 = image.new(context: context)
      my_image2.download
    end
  end

  describe '#tag' do
    let(:image_obj) { double('::Docker::Image') }

    it 'tags the Docker Image' do
      expect(::Docker::Image).to receive(:get).and_return(image_obj)
      expect(image_obj).to receive(:tag).with(repo: 'docker/demo', tag: 'mytag')
      my_image = image.new(name: 'docker/demo')
      my_image.tag('mytag')
    end
  end

  describe '#build' do
    it 'builds an image based on a Docker Context' do
      expect(::Docker::Image).to receive(:build_from_dir).with('/tmp/docker/demo')
      my_image = image.new(context: context)
      my_image.build
    end

    it 'raises an error if used without a Docker Context' do
      bad_image = image.new(name: 'docker/demo')
      expect{ bad_image.build }.to raise_error KnifeContainer::Exceptions::PluginError
    end
  end

  describe '#rebase' do
    let(:current_img) { double('::Docker::Image') }
    let(:base_img) { double('::Docker::Image') }

    it 'rebases a Docker Context on a new base image' do
      expect(::Docker::Image).to receive(:create).with(fromImage: 'chef/base_image').and_return(base_img)
      expect(::Docker::Image).to receive(:get).with('docker/demo').and_return(current_img)
      expect(current_img).to receive(:remove)
      expect(base_img).to receive(:tag).with(repo: 'docker/demo', tag: 'latest')
      my_image = image.new(context: context)
      my_image.rebase
    end

    it 'raises an error if used without a Docker Context' do
      bad_image = image.new(name: 'docker/demo')
      expect{ bad_image.rebase }.to raise_error KnifeContainer::Exceptions::PluginError
    end
  end
end
