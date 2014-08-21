
module KnifeContainer

  module Helpers
    #
    # Generates a short, but random UID for instances.
    #
    # @return [String]
    #
    def random_uid
      require 'securerandom' unless defined?(SecureRandom)
      SecureRandom.hex(3)
    end


    #
    # Determines whether the Docker image name the user gave is valid.
    #
    def valid_dockerfile_name?(name)
      case
      when name.match(/:([a-zA-Z0-9._\-]+)?$/) # Does it have a tag?
        false
      when name.match(/^\w+:\/\//) # Does it include a protocol?
        false
      else
        true
      end
    end

    #
    # Converts the dockerfile name into something safe
    #
    def encoded_dockerfile_name(name)
      name.gsub(/[\.\:]/, '_')
    end
  end
end
