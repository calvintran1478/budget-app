require "validator"

module Schemas::UserSchemas
  MAX_EMAIL_LENGTH = 60
  MIN_PASSWORD_LENGTH = 8
  MAX_PASSWORD_LENGTH = 71
  MAX_FIRST_NAME_LENGTH = 50
  MAX_LAST_NAME_LENGTH = 50

  # Request body schema for POST requests sent to /api/v1/users
  struct RegisterRequest
    getter email : String
    getter password : String
    getter first_name : String
    getter last_name : String

    def initialize(@email : String, @password : String, @first_name : String, @last_name : String)
    end

    def RegisterRequest.from_context(context : HTTP::Server::Context) : (RegisterRequest | Nil)
      # Get request body
      if context.request.body.nil?
        context.response.status = HTTP::Status::BAD_REQUEST
        return
      end
      request_body = context.request.body.as(IO)

      # Parse and validate email
      email = request_body.gets('\n', MAX_EMAIL_LENGTH + 1, chomp: true)
      if email.nil?
        context.response.status = HTTP::Status::BAD_REQUEST
        context.response.output << "Email required"
        return
      elsif !Valid.email?(email)
        context.response.status = HTTP::Status::BAD_REQUEST
        context.response.output << "Invalid email"
        return
      end

      # Parse and validate password
      password = request_body.gets('\n', MAX_PASSWORD_LENGTH + 1, chomp: true)
      if password.nil?
        context.response.status = HTTP::Status::BAD_REQUEST
        context.response.output << "Password required"
        return
      elsif password.size < MIN_PASSWORD_LENGTH
        context.response.status = HTTP::Status::BAD_REQUEST
        context.response.output << "Password must be at least 8 characters"
        return
      elsif password.size > MAX_PASSWORD_LENGTH
        context.response.status = HTTP::Status::BAD_REQUEST
        context.response.output << "Password cannot exceed 71 characters"
        return
      end

      # Parse and validate first name
      first_name = request_body.gets('\n', MAX_FIRST_NAME_LENGTH + 1, chomp: true)
      if first_name.nil?
        context.response.status = HTTP::Status::BAD_REQUEST
        context.response.output << "First name required"
        return
      elsif first_name.empty?
        context.response.status = HTTP::Status::BAD_REQUEST
        context.response.output << "First name cannot be empty"
        return
      elsif first_name.size > MAX_FIRST_NAME_LENGTH
        context.response.status = HTTP::Status::BAD_REQUEST
        context.response.output << "First name cannot exceed 50 characters"
        return
      elsif first_name.each_char.any? { |ch| !ch.ascii_letter? }
        context.response.status = HTTP::Status::BAD_REQUEST
        context.response.output << "First name must consist of alphabetical characters"
        return
      end

      # Parse and validate last name
      last_name = request_body.gets('\n', MAX_LAST_NAME_LENGTH + 1, chomp: true)
      if last_name.nil?
        context.response.status = HTTP::Status::BAD_REQUEST
        context.response.output << "Last name required"
        return
      elsif last_name.empty?
        context.response.status = HTTP::Status::BAD_REQUEST
        context.response.output << "Last name cannot be empty"
        return
      elsif last_name.size > MAX_LAST_NAME_LENGTH
        context.response.status = HTTP::Status::BAD_REQUEST
        context.response.output << "Last name cannot exceed 50 characters"
        return
      elsif last_name.each_char.any? { |ch| !ch.ascii_letter? }
        context.response.status = HTTP::Status::BAD_REQUEST
        context.response.output << "Last name must consist of alphabetical characters"
        return
      end

      RegisterRequest.new(email, password, first_name, last_name)
    end
  end

  # Response body schema for server responses to /api/v1/users POSt requests.
  struct RegisterResponse
    def initialize(@email : String, @first_name : String, @last_name : String)
    end

    def to_s(io : IO) : Nil
      io << @email << '\n' << @first_name << '\n' << @last_name
    end
  end
end
