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

require 'knife-container/generator'
require 'knife-container/chef_runner'

module KnifeContainer
  module Command

    # An instance of ChefRunner. Calling ChefRunner#converge will trigger
    # convergence and generate the desired code.
    def chef_runner
      @chef_runner ||= ChefRunner.new(docker_cookbook_path, ["knife_container::#{recipe}"])
    end

    # Path to the directory where the code_generator cookbook is located.
    # For now, this is hard coded to the 'skeletons' directory in this
    # repo.
    def docker_cookbook_path
      File.expand_path('../skeletons', __FILE__)
    end

    # Delegates to `Generator.context`, the singleton instance of
    # Generator::Context
    def generator_context
      Generator.context
    end

  end
end
