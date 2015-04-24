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
require 'knife-container/plugins/berkshelf'

describe KnifeContainer::Plugins::Berkshelf do

  let(:berkshelf) { KnifeContainer::Plugins::Berkshelf }

  describe '.validate!' do
    it 'raises error is Berkshelf is not installed' do
      allow(berkshelf).to receive(:installed?).and_return(false)
      expect{ berkshelf.validate! }.to raise_error KnifeContainer::Exceptions::ValidationError
    end
  end

  describe '.installed?' do
    it 'returns whether or not Berkshelf is installed' do
      allow(MakeMakefile).to receive(:find_executable).with('berks').and_return(nil)
      expect(berkshelf.installed?).to eql(false)
      allow(MakeMakefile).to receive(:find_executable).with('berks').and_return('/usr/bin/berks')
      expect(berkshelf.installed?).to eql(true)
    end
  end
end
