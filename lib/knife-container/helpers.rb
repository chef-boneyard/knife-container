
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

  end
end
