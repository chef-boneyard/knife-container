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

module KnifeContainer

  module Generator

    class Context

      attr_accessor :dockerfile_name
      attr_accessor :dockerfiles_path
      attr_accessor :base_image
      attr_accessor :chef_client_mode
      attr_accessor :run_list
      attr_accessor :cookbook_path
      attr_accessor :role_path
      attr_accessor :node_path
      attr_accessor :environment_path
      attr_accessor :chef_server_url
      attr_accessor :validation_key
      attr_accessor :validation_client_name
      attr_accessor :trusted_certs_dir
      attr_accessor :encrypted_data_bag_secret
      attr_accessor :first_boot
      attr_accessor :berksfile
      attr_accessor :berksfile_source
      attr_accessor :generate_berksfile
      attr_accessor :run_berks
      attr_accessor :force_build
      attr_accessor :include_credentials

    end

    def self.reset
      @context = nil
    end

    def self.context
      @context ||= Context.new
    end

    module TemplateHelper

      def self.delegate_to_app_context(name)
        define_method(name) do
          KnifeContainer::Generator.context.public_send(name)
        end
      end

      # delegate all the attributes of app_config
      delegate_to_app_context :dockerfile_name
      delegate_to_app_context :dockerfiles_path
      delegate_to_app_context :base_image
      delegate_to_app_context :chef_client_mode
      delegate_to_app_context :run_list
      delegate_to_app_context :cookbook_path
      delegate_to_app_context :role_path
      delegate_to_app_context :node_path
      delegate_to_app_context :environment_path
      delegate_to_app_context :chef_server_url
      delegate_to_app_context :validation_key
      delegate_to_app_context :validation_client_name
      delegate_to_app_context :trusted_certs_dir
      delegate_to_app_context :encrypted_data_bag_secret
      delegate_to_app_context :first_boot
      delegate_to_app_context :berksfile
      delegate_to_app_context :berksfile_source
      delegate_to_app_context :generate_berksfile
      delegate_to_app_context :run_berks
      delegate_to_app_context :force_build
      delegate_to_app_context :include_credentials

    end

  end
end
