require "base64"

module Utils::Token
  extend self

  USER_ID_LENGTH = 36

  # Claims stored within an access token
  struct AccessClaims
    getter user_id : String
    getter exp : Int64

    def initialize(@user_id : String, @exp : Int64)
    end

    # Creates an access token from self, which is signed using the provided key.
    #
    # The contents of the token are written to the given IO.
    def encode(key : String, io : IO) : Nil
      # Create encoded payload
      buffer = uninitialized UInt8[8]
      exp_bytes = Bytes.new(buffer.to_unsafe, 8)
      IO::ByteFormat::NetworkEndian.encode(@exp, exp_bytes)
      encoded_payload = @user_id + Base64.urlsafe_encode(exp_bytes, false)

      # Write encoded payload and signature to the provided IO
      io << encoded_payload
      io << Base64.urlsafe_encode(OpenSSL::HMAC.digest(:sha256, key, encoded_payload), false)
    end

    # Parses the provided access token for its contents.
    #
    # Returns whether the provided token is valid.
    def AccessClaims.decode(token : Pointer(UInt8), key : String) : Bool
      # Parse token into its two segments
      encoded_payload = Bytes.new(token, 47)
      encoded_signature = Bytes.new(token + 47, 43)

      # Verify signature
      expected_encoded_signature = Base64.urlsafe_encode(OpenSSL::HMAC.digest(:sha256, key, encoded_payload), false)
      return false if !Crypto::Subtle.constant_time_compare(encoded_signature, expected_encoded_signature)

      # Validate payload
      encoded_exp = Bytes.new(encoded_payload.to_unsafe + USER_ID_LENGTH, 11)
      exp = IO::ByteFormat::NetworkEndian.decode(Int64, Base64.decode(encoded_exp))
      return false if exp < Time.utc.to_unix

      true
    end
  end
end
