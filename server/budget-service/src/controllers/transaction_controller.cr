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
    when {"GET", _}
      if path.size == 0 || path.unsafe_fetch(0) == '?'.ord
        get_transactions(context)
      else
        context.response.status = HTTP::Status::NOT_FOUND
      end
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
  # Start and end times can optionaly be provided to select transactions within
  # a given range. If start time is excluded, then transactions up until the
  # oldest transaction will be included. Likewise, if end time is exlcuded, then
  # transactions up until the most recent transaction will be included.
  #
  # If start and/or end times are provided, they should be of the from %Y-%m-%d
  # (e.g., 2026-05-06).
  #
  # Method: GET
  # Path: /api/v1/transactions?start={start_time}&end={end_time}
  def get_transactions(context : HTTP::Server::Context) : Nil
    # Get user
    user_id_buffer = uninitialized UInt8[USER_ID_STRING_LENGTH]
    user_id = @auth_middleware.get_user(context, user_id_buffer.to_unsafe)
    return if user_id.nil?

    # Parse query parameters
    begin
      start_time_param = context.request.query_params["start"]?
      start_time = start_time_param.nil? ? Time.unix(0) : Time.parse_utc(start_time_param, "%F")
    rescue Time::Format::Error
      context.response.status = HTTP::Status::BAD_REQUEST
      context.response.output << "Invalid start time"
      return
    end

    begin
      end_time_param = context.request.query_params["end"]?
      end_time = end_time_param.nil? ? Time.utc : Time.parse_utc(end_time_param, "%F")
    rescue Time::Format::Error
      context.response.status = HTTP::Status::BAD_REQUEST
      context.response.output << "Invalid end time"
      return
    end

    # Send transactions
    context.response.content_type = "application/octect-stream"
    context.response.status = HTTP::Status::OK
    @transaction_repository.list(user_id, start_time, end_time, context.response.output)
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
