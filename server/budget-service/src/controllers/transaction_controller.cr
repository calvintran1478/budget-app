require "../schemas/transaction_schemas"

struct Controllers::TransactionController
  include Schemas::TransactionSchemas

  ADD_TRANSACTION_REQUEST_BUFFER_SIZE = 247 # MAX_ADD_TRANSACTION_REQUEST_BODY_SIZE + 1
  USER_ID_STRING_LENGTH = 49
  TRANSACTION_ID_LENGTH = 22

  def initialize(@transaction_repository : Repositories::TransactionRepository, @auth_middleware : Middleware::AuthMiddleware)
    @prefix_length = "/api/v1/transactions".size
  end

  def handle_request(context : HTTP::Server::Context) : Nil
    # Get distinguishing path from resource string
    path = context.request.resource.unsafe_byte_slice(@prefix_length)

    # Call appropriate request handler
    case {context.request.method, path}
    when {"POST", "".to_slice}
      add_transaction(context)
    when {"GET", "".to_slice}
      get_transactions(context)
    when {"PATCH", _}
      if path.size == 1 + TRANSACTION_ID_LENGTH && path.unsafe_fetch(0) == '/'.ord
        update_transcation(context, String.new(path.to_unsafe + 1, TRANSACTION_ID_LENGTH))
      else
        context.response.status = HTTP::Status::NOT_FOUND
      end
    when {"DELETE", _}
      if path.size == 1 + TRANSACTION_ID_LENGTH && path.unsafe_fetch(0) == '/'.ord
        delete_transaction(context, String.new(path.to_unsafe + 1, TRANSACTION_ID_LENGTH))
      else
        context.response.status = HTTP::Status::NOT_FOUND
      end
    else
      context.response.status = HTTP::Status::NOT_FOUND
    end
  end

  # Adds a transaction for the user.
  #
  # Method: POST
  # Path: /api/v1/transactions
  def add_transaction(context : HTTP::Server::Context) : Nil
    # Get user
    user_id_buffer = uninitialized UInt8[USER_ID_STRING_LENGTH]
    user_id = @auth_middleware.get_user(context, user_id_buffer.to_unsafe)
    return if user_id.nil?

    # Validate user input
    add_transaction_request_buffer = uninitialized UInt8[ADD_TRANSACTION_REQUEST_BUFFER_SIZE]
    data = AddTransactionRequest.from_context(context, add_transaction_request_buffer.to_unsafe)
    return if data.nil?

    # Add transaction
    transaction_id = @transaction_repository.create(user_id, data.name, data.category, data.amount, data.currency)

    # Send success response
    context.response.content_type = "text/plain"
    context.response.status = HTTP::Status::CREATED
    context.response.output << transaction_id
  end

  # Retreives transactions for the user.
  #
  # Method: GET
  # Path: /api/v1/transactions
  def get_transactions(context : HTTP::Server::Context) : Nil
    # Get user
    user_id_buffer = uninitialized UInt8[USER_ID_STRING_LENGTH]
    user_id = @auth_middleware.get_user(context, user_id_buffer.to_unsafe)
    return if user_id.nil?

    # Send transactions
    context.response.content_type = "application/octect-stream"
    context.response.status = HTTP::Status::OK
    @transaction_repository.list(user_id, context.response.output)
  end

  # Updates a transaction for the user.
  #
  # Method: PATCH
  # Path: /api/v1/transactions/{transaction_id}
  def update_transcation(context : HTTP::Server::Context, transaction_id : String) : Nil
    # Get user
    user_id_buffer = uninitialized UInt8[USER_ID_STRING_LENGTH]
    user_id = @auth_middleware.get_user(context, user_id_buffer.to_unsafe)
    return if user_id.nil?

    # Validate user input
    data = UpdateTransactionRequest.from_context(context)
    return if data.nil?

    # Update transaction
    unless @transaction_repository.update(user_id, transaction_id, data.name, data.category, data.amount, data.currency, data.date)
      context.response.status = HTTP::Status::NOT_FOUND
      context.response.output << "Transaction not found"
      return
    end

    # Send success response
    context.response.status = HTTP::Status::NO_CONTENT
  end

  # Deletes a transaction for the user.
  #
  # Method: Delete
  # Path: /api/v1/transactions/{transaction_id}
  def delete_transaction(context : HTTP::Server::Context, transaction_id : String) : Nil
    # Get user
    user_id_buffer = uninitialized UInt8[USER_ID_STRING_LENGTH]
    user_id = @auth_middleware.get_user(context, user_id_buffer.to_unsafe)
    return if user_id.nil?

    # Delete transaction
    unless @transaction_repository.delete(user_id, transaction_id)
      context.response.status = HTTP::Status::NOT_FOUND
      context.response.output << "Transaction not found"
      return
    end

    # Send success response
    context.response.status = HTTP::Status::NO_CONTENT
  end
end
