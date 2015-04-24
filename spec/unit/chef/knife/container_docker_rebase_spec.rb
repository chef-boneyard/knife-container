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
require 'chef/knife/container_docker_rebase'
Chef::Knife::ContainerDockerRebase.load_deps

describe Chef::Knife::ContainerDockerRebase do

  let(:stdout_io) { StringIO.new }

  def stdout
    stdout_io.string
  end

  subject(:knife) do
    Chef::Knife::ContainerDockerRebase.new(argv).tap do |c|
      allow(c).to receive(:output).and_return(true)
      allow(c.ui).to receive(:stdout).and_return(stdout_io)
    end
  end

  describe '#run' do
    let(:argv) { %w[ docker/demo ] }

    it 'validates arguments then redownloads and retags the docker image' do
      expect(knife).to receive(:validate!)
      expect(knife).to receive(:rebase_docker_image)
      knife.run
    end
  end
end
