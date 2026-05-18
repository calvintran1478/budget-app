require "base64"

module Utils::Token
  extend self

  USER_ID_LENGTH = 36
  TOKEN_FAMILY_ID_LENGTH = 36

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

  # Claims stored within a refresh token
  struct RefreshClaims
    getter user_id : String
    getter token_family_id : String
    getter sequence_number : Int32
    getter exp : Int64

    def initialize(@user_id : String, @token_family_id : String, @sequence_number : Int32, @exp : Int64)
    end

    # Creates a refresh token from the provided refresh claims, which are signed
    # using the provided key.
    #
    # The contents of the token are returned as a string
    def encode(key : String) : String
      bytesize = 132
      String.new(bytesize) do |buffer|
        curr_buffer = buffer

        # Encode payload
        curr_buffer.copy_from(@user_id.to_unsafe, USER_ID_LENGTH)
        curr_buffer += USER_ID_LENGTH

        curr_buffer.copy_from(@token_family_id.to_unsafe, TOKEN_FAMILY_ID_LENGTH)
        curr_buffer += TOKEN_FAMILY_ID_LENGTH

        int_buffer = uninitialized UInt8[8]
        sequence_bytes = Bytes.new(int_buffer.to_unsafe, 4)
        IO::ByteFormat::NetworkEndian.encode(@sequence_number, sequence_bytes)
        encoded_sequence_number = Base64.urlsafe_encode(sequence_bytes, false)
        curr_buffer.copy_from(encoded_sequence_number.to_unsafe, encoded_sequence_number.size)
        curr_buffer += encoded_sequence_number.size

        exp_bytes = Bytes.new(int_buffer.to_unsafe, 8)
        IO::ByteFormat::NetworkEndian.encode(@exp, exp_bytes)
        encoded_exp = Base64.urlsafe_encode(exp_bytes, false)
        curr_buffer.copy_from(encoded_exp.to_unsafe, encoded_exp.size)
        curr_buffer += encoded_exp.size

        # Encode signature
        encoded_payload = Bytes.new(buffer, 89)
        encoded_signature = Base64.urlsafe_encode(OpenSSL::HMAC.digest(:sha256, key, encoded_payload), false)
        curr_buffer.copy_from(encoded_signature.to_unsafe, encoded_signature.size)

        {132, 132}
      end
    end

    # Parses the provided refresh token for its contents.
    #
    # Upon success this returns the refresh claims of the token. Otherwise this
    # function returns nil.
    def RefreshClaims.decode(token : Pointer(UInt8), key : String) : (RefreshClaims | Nil)
      # Parse token into its two segments
      encoded_payload = Bytes.new(token, 89)
      encoded_signature = Bytes.new(token + 89, 43)

      # Verify signature
      expected_encoded_signature = Base64.urlsafe_encode(OpenSSL::HMAC.digest(:sha256, key, encoded_payload), false)
      return if !Crypto::Subtle.constant_time_compare(encoded_signature, expected_encoded_signature)

      # Decode payload claims
      curr_buffer = encoded_payload.to_unsafe

      user_id = String.new(curr_buffer, USER_ID_LENGTH)
      curr_buffer += USER_ID_LENGTH

      token_family_id = String.new(curr_buffer, TOKEN_FAMILY_ID_LENGTH)
      curr_buffer += TOKEN_FAMILY_ID_LENGTH

      encoded_sequence_number = Bytes.new(curr_buffer, 6)
      sequence_number = IO::ByteFormat::NetworkEndian.decode(Int32, Base64.decode(encoded_sequence_number))
      curr_buffer += 6

      encoded_exp = Bytes.new(curr_buffer, 11)
      exp = IO::ByteFormat::NetworkEndian.decode(Int64, Base64.decode(encoded_exp))

      # Validate payload
      return if exp < Time.utc.to_unix

      RefreshClaims.new(user_id, token_family_id, sequence_number, exp)
    end
  end
end
