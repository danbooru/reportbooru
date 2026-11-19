# frozen_string_literal: true

require "test_helper"

class MessageVerifierTest < Minitest::Test
  def setup
    @verifier = Reportbooru::MessageVerifier.new("testkey")
  end

  def test_verifies_danbooru_signatures
    DANBOORU_SIGNATURES.each do |message, signature|
      assert_equal message, @verifier.verify(signature)
    end
  end

  def test_generates_the_same_signatures_as_danbooru
    DANBOORU_SIGNATURES.each do |message, signature|
      assert_equal signature, @verifier.generate(message)
    end
  end

  def test_rejects_bad_signatures
    signature = DANBOORU_SIGNATURES["12345,abc123"]
    data, digest = signature.split("--")

    [
      Reportbooru::MessageVerifier.new("wrongkey").generate("12345,abc123"),
      "#{data}--#{digest.reverse}",
      "#{data}--",
      "#{[JSON.generate("99999,abc123")].pack("m0")}--#{digest}",
      data,
      "--#{digest}",
      "",
      "not base64--#{OpenSSL::HMAC.hexdigest("SHA256", "testkey", "not base64")}",
      "#{["not json"].pack("m0")}--#{OpenSSL::HMAC.hexdigest("SHA256", "testkey", ["not json"].pack("m0"))}",
      DANBOORU_SIGNATURE_WITH_PURPOSE,
      nil,
      ["12345,abc123"],
    ].each do |bad|
      assert_raises(Reportbooru::MessageVerifier::InvalidSignature, "accepted #{bad.inspect}") { @verifier.verify(bad) }
    end
  end

  def test_requires_a_secret
    assert_raises(ArgumentError) { Reportbooru::MessageVerifier.new(nil) }
    assert_raises(ArgumentError) { Reportbooru::MessageVerifier.new("") }
  end
end
