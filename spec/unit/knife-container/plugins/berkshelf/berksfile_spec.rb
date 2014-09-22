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
require 'knife-container/plugins/berkshelf/berksfile'

describe KnifeContainer::Plugins::Berkshelf::Berksfile do

  subject(:berks) { KnifeContainer::Plugins::Berkshelf::Berksfile }
  let(:berksfile) { "#{fixtures_path}/Berksfile" }

  describe '#new' do
    it 'accepts one parameter, the path to the Berksfile' do
      expect { berks.new }.to raise_error
      myberks = berks.new(berksfile)
      expect(myberks.berksfile).to eql(berksfile)
    end

    it 'raises Exception when Berksfile cannot be found' do
      allow(File).to receive(:exist?).with(berksfile).and_return(false)
      expect{ berks.new(berksfile) }.to raise_error KnifeContainer::Exceptions:: ValidationError
    end
  end

  describe 'configuration options' do
    it 'accepts force' do
      myberks = berks.new(berksfile)
      myberks.force = true
    end

    it 'accepts config' do
      myberks = berks.new(berksfile)
      myberks.config = '/tmp/example/berks.config'
    end
  end

  describe '#install' do
    it 'runs the Berkshelf install command' do
      myberks = berks.new(berksfile)
      expect(myberks).to receive(:run_command).with('berks install')
      myberks.install
    end
  end

  describe '#upload' do
    it 'runs the Berkshelf upload command' do
      myberks = berks.new(berksfile)
      expect(myberks).to receive(:install)
      expect(myberks).to receive(:run_command).with('berks upload')
      myberks.upload
    end

    it 'honors the force and config options' do
      myberks = berks.new(berksfile)
      myberks.force = true
      myberks.config = '/tmp/example/berkshelf.config'
      expect(myberks).to receive(:install)
      expect(myberks).to receive(:run_command).with('berks upload --force --config=/tmp/example/berkshelf.config')
      myberks.upload
    end
  end

  describe '#vendor' do
    it 'runs the Berkshelf vendor command' do
      myberks = berks.new(berksfile)
      expect(myberks).to receive(:install)
      expect(myberks).to receive(:run_command).with('berks vendor /tmp/target')
      myberks.vendor('/tmp/target')
    end

    it 'honors the force and config options' do
      myberks = berks.new(berksfile)
      myberks.force = true
      myberks.config = '/tmp/example/berkshelf.config'
      expect(myberks).to receive(:install)
      expect(myberks).to receive(:run_command).with('berks vendor /tmp/target --force --config=/tmp/example/berkshelf.config')
      myberks.vendor('/tmp/target')
    end

    context 'when target path already exists' do
      before do
        allow(File).to receive(:exist?).with(berksfile).and_return(true)
        allow(File).to receive(:exist?).with('/tmp/target').and_return(true)
      end

      it 'raises PluginError exception' do
        myberks = berks.new(berksfile)
        expect{ myberks.vendor('/tmp/target') }.to raise_error KnifeContainer::Exceptions::PluginError
      end
    end
  end

end
