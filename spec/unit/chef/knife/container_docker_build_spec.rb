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
require 'chef/knife/container_docker_build'
Chef::Knife::ContainerDockerBuild.load_deps

describe Chef::Knife::ContainerDockerBuild do

  subject(:knife) do
    Chef::Knife::ContainerDockerBuild.new(argv).tap do |c|
      c.parse_options(argv)
      c.merge_configs
    end
  end

  describe '#run' do
    before(:each) do
      Chef::Config.reset
      Chef::Config[:chef_repo_path] = tempdir
    end

    context 'by default' do
      let(:argv) { %w[ docker/demo ] }

      it 'parses argv, builds the image and removes the artifacts' do
        expect(knife).to receive(:validate!)
        expect(knife).not_to receive(:backup_secure)
        expect(knife).to receive(:validate_and_run_berkshelf)
        expect(knife).to receive(:validate_and_run_docker)
        expect(knife).not_to receive(:restore_secure)
        expect(knife).to receive(:cleanup_artifacts)
        knife.run
      end
    end

    context 'when argv is empty' do
      let(:argv) { %w[] }

      it 'errors out' do
        lambda do
          expect(knife).to receive(:error_out)
          knife.run
        end
      end
    end

    context '--no-berks is passed' do
      let(:argv) { %w[ docker/demo --no-berks ] }

      it 'does not run berkshelf' do
        expect(knife).to receive(:validate!)
        expect(knife).not_to receive(:backup_secure)
        expect(knife).not_to receive(:validate_and_run_berkshelf)
        expect(knife).to receive(:validate_and_run_docker)
        expect(knife).not_to receive(:restore_secure)
        expect(knife).to receive(:cleanup_artifacts)
        knife.run
      end
    end

    context '--no-cleanup is passed' do
      let(:argv) { %w[ docker/demo --no-cleanup ] }

      it 'does not clean up the artifacts' do
        expect(knife).to receive(:validate!)
        expect(knife).not_to receive(:backup_secure)
        expect(knife).to receive(:validate_and_run_berkshelf)
        expect(knife).to receive(:validate_and_run_docker)
        expect(knife).not_to receive(:restore_secure)
        expect(knife).not_to receive(:cleanup_artifacts)
        knife.run
      end
    end

    context 'when --secure-dir is passed' do
      let(:argv) { %w[ docker/demo --secure-dir /path/to/dir ] }

      it 'uses contents of specified directory for secure credentials during build' do
        expect(knife).to receive(:validate!)
        expect(knife).to receive(:backup_secure)
        expect(knife).to receive(:validate_and_run_berkshelf)
        expect(knife).to receive(:validate_and_run_docker)
        expect(knife).to receive(:restore_secure)
        expect(knife).to receive(:cleanup_artifacts)
        knife.run
      end
    end
  end
end
