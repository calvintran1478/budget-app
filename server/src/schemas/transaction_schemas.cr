require "../utils/buffer"

module Schemas::TransactionSchemas
  ADD_TRANSACTION_REQUEST_BUFFER_SIZE = 247 # MAX_ADD_TRANSACTION_REQUEST_BODY_SIZE + 1

  MIN_ADD_TRANSACTION_REQUEST_BODY_SIZE = 8
  MAX_ADD_TRANSACTION_REQUEST_BODY_SIZE = 246 # 4 + 1 + MAX_NAME_SIZE + 1 + MAX_CATEGORY_SIZE

  MAX_NAME_SIZE = 120
  MAX_CATEGORY_SIZE = 120

  CURRENCIES = StaticArray["CAD", "USD"]

  struct AddTransactionRequest
    getter name : String
    getter category : String
    getter amount : Int32
    getter currency : String

    def initialize(@name : String, @category : String, @amount : Int32, @currency : String)
    end

    def AddTransactionRequest.from_context(context : HTTP::Server::Context, add_transaction_request_buffer : UInt8*) : (AddTransactionRequest | Nil)
      # Get request body
      if context.request.body.nil?
        context.response.status = HTTP::Status::BAD_REQUEST
        return
      end
      request_body = context.request.body.as(IO)

      # Read request body bytes
      bytesize = Utils::Buffer.read_io_to_buffer(request_body, add_transaction_request_buffer, ADD_TRANSACTION_REQUEST_BUFFER_SIZE)
      if bytesize < MIN_ADD_TRANSACTION_REQUEST_BODY_SIZE || bytesize > MAX_ADD_TRANSACTION_REQUEST_BODY_SIZE
        context.response.status = HTTP::Status::BAD_REQUEST
        context.response.output << "Payload must be between 8 and 245 bytes"
        return
      end

      # Read amount
      amount = IO::ByteFormat::NetworkEndian.decode(Int32, Bytes.new(add_transaction_request_buffer, 4))
      if amount <= 0
        context.response.status = HTTP::Status::BAD_REQUEST
        context.response.output << "Amount must be positive"
        return
      end

      # Read currency
      currency_index = add_transaction_request_buffer[4]
      if currency_index >= 2
        context.response.status = HTTP::Status::BAD_REQUEST
        context.response.output << "The provided currency is not supported"
        return
      end
      currency = CURRENCIES[currency_index]

      # Search for newline character separating name and category
      newline_ptr = LibC.memchr(add_transaction_request_buffer + 5, '\n'.ord.to_u8, bytesize - 5).as(UInt8*)
      if newline_ptr.null?
        context.response.status = HTTP::Status::BAD_REQUEST
        context.response.output << "Category required"
        return
      end

      # Read name
      name_length = newline_ptr - (add_transaction_request_buffer + 5)
      if name_length == 0
        context.response.status = HTTP::Status::BAD_REQUEST
        context.response.output << "Name cannot be empty"
        return
      elsif name_length > MAX_NAME_SIZE
        context.response.status = HTTP::Status::BAD_REQUEST
        context.response.output << "Name can be at most 120 characters"
        return
      end
      name = String.new(add_transaction_request_buffer + 5, name_length)

      # Read category
      category_length = bytesize - 6 - name_length
      if category_length == 0
        context.response.status = HTTP::Status::BAD_REQUEST
        context.response.output << "Category cannot be empty"
        return
      elsif category_length > MAX_CATEGORY_SIZE
        context.response.status = HTTP::Status::BAD_REQUEST
        context.response.output << "Category can be at most 120 characters"
        return
      end
      category = String.new(newline_ptr + 1, category_length)

      AddTransactionRequest.new(name, category, amount, currency)
    end
  end
end
