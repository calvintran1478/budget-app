
module Schemas::CategorySchemas
  ADD_CATEGORY_REQUEST_BUFFER_SIZE = 126 # MAX_ADD_CATEGORY_REQUEST_BODY_SIZE + 1

  MIN_ADD_CATEGORY_REQUEST_BODY_SIZE = 6
  MAX_ADD_CATEGORY_REQUEST_BODY_SIZE = 125 # 4 + 1 + MAX_CATEGORY_SIZE

  MAX_NAME_SIZE = 120

  # Request body schema for POST requests sent to /api/v1/categories
  struct AddCategoryRequest
    getter name : String
    getter spending_limit : Int32 # Monthly spending limit
    getter currency_index : Int32

    def initialize(@name : String, @spending_limit : Int32, @currency_index : Int32)
    end

    def AddCategoryRequest.from_context(context : HTTP::Server::Context, add_category_request_buffer : UInt8*) : (AddCategoryRequest | Nil)
      # Get request body
      if context.request.body.nil?
        context.response.status = HTTP::Status::BAD_REQUEST
        return
      end
      request_body = context.request.body.as(IO)

      # Read request body bytes
      bytesize = Utils::Buffer.read_io_to_buffer(request_body, add_category_request_buffer, ADD_CATEGORY_REQUEST_BUFFER_SIZE)
      if bytesize < MIN_ADD_CATEGORY_REQUEST_BODY_SIZE || bytesize > MAX_ADD_CATEGORY_REQUEST_BODY_SIZE
        context.response.status = HTTP::Status::BAD_REQUEST
        context.response.output << "Payload must be between 6 and 125 bytes"
        return
      end

      # Read spending limit
      spending_limit = IO::ByteFormat::NetworkEndian.decode(Int32, Bytes.new(add_category_request_buffer, 4))
      if spending_limit <= 0
        context.response.status = HTTP::Status::BAD_REQUEST
        context.response.output << "Amount must be positive"
        return
      end

      # Read currency
      currency_index = add_category_request_buffer[4]
      if currency_index >= 2
        context.response.status = HTTP::Status::BAD_REQUEST
        context.response.output << "The provided currency is not supported"
        return
      end

      # Read name
      name = String.new(add_category_request_buffer + 5, bytesize - 5)

      AddCategoryRequest.new(name, spending_limit, currency_index)
    end
  end

  # Request body schema for PATCH requests sent to /api/v1/categories/{category_id}
  struct UpdateCategoryRequest
    include JSON::Serializable

    getter name : (String | Nil)
    getter spending_limit : (Int32 | Nil)
    getter currency_index : (Int32 | Nil)

    def initialize(@name : String?, @spending_limit : Int32?, @currency_index : Int32?)
    end

    def UpdateCategoryRequest.from_context(context : HTTP::Server::Context) : (UpdateCategoryRequest | Nil)
      # Get request body
      if context.request.body.nil?
        context.response.status = HTTP::Status::BAD_REQUEST
        return
      end
      request_body = context.request.body.as(IO)

      # Parse JSON
      begin
        data = UpdateCategoryRequest.from_json(request_body)
      rescue JSON::ParseException | Time::Format::Error
        context.response.status = HTTP::Status::BAD_REQUEST
        return
      end

      # Validate request body
      if !data.spending_limit.nil? && data.currency_index.nil?
        context.response.status = HTTP::Status::BAD_REQUEST
        context.response.output << "Missing currency index"
        return
      elsif data.spending_limit.nil? && !data.currency_index.nil?
        context.response.status = HTTP::Status::BAD_REQUEST
        context.response.output << "Missing spending limit"
        return
      end

      unless data.name.nil?
        name = data.name.as(String)
        if name.size == 0
          context.response.status = HTTP::Status::BAD_REQUEST
          context.response.output << "Name cannot be empty"
          return
        elsif name.size > MAX_NAME_SIZE
          context.response.status = HTTP::Status::BAD_REQUEST
          context.response.output << "Name can be at most 120 characters"
          return
        end
      end

      unless data.spending_limit.nil?
        if data.spending_limit.as(Int32) <= 0
          context.response.status = HTTP::Status::BAD_REQUEST
          context.response.output << "Amount must be positive"
          return
        elsif data.currency_index.as(Int32) >= 2
          context.response.status = HTTP::Status::BAD_REQUEST
          context.response.output << "The provided currency is not supported"
          return
        end
      end

      data
    end
  end
end
