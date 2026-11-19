# frozen_string_literal: true

require "json"
require "openssl"
require "rack/utils"

module Reportbooru
  # Verifies messages signed by Danbooru with
  # `ActiveSupport::MessageVerifier.new(key, serializer: JSON, digest: "SHA256")`.
  #
  # A signed message is "<base64 of the JSON-encoded string>--<hex HMAC-SHA256 of the base64 part>".
  #
  # @see https://api.rubyonrails.org/classes/ActiveSupport/MessageVerifier.html
  class MessageVerifier
    class InvalidSignature < StandardError; end

    SEPARATOR = "--"

    def initialize(secret)
      raise ArgumentError, "secret is blank" if secret.to_s.empty?

      @secret = secret
    end

    # @param signed_message [String] the signed message from Danbooru
    # @return [String] the original message
    # @raise [InvalidSignature] if the message is malformed or the signature doesn't match
    def verify(signed_message)
      raise InvalidSignature unless signed_message.is_a?(String)

      data, separator, digest = signed_message.rpartition(SEPARATOR)
      raise InvalidSignature if separator.empty? || data.empty?
      raise InvalidSignature unless Rack::Utils.secure_compare(generate_digest(data), digest)

      message = JSON.parse(data.unpack1("m0").force_encoding(Encoding::UTF_8))

      # Messages signed with a purpose or expiry are wrapped in a hash. Danbooru doesn't use those.
      raise InvalidSignature unless message.is_a?(String)

      message
    rescue ArgumentError, JSON::ParserError
      raise InvalidSignature
    end

    # @param message [String] the message to sign
    # @return [String] the signed message, in the same format Danbooru generates
    def generate(message)
      data = [JSON.generate(message)].pack("m0")
      "#{data}#{SEPARATOR}#{generate_digest(data)}"
    end

    private

    def generate_digest(data)
      OpenSSL::HMAC.hexdigest("SHA256", @secret, data)
    end
  end
end
