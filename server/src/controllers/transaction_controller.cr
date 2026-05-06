require "../schemas/transaction_schemas"

struct Controllers::TransactionController
  include Schemas::TransactionSchemas

  ADD_TRANSACTION_REQUEST_BUFFER_SIZE = 247 # MAX_ADD_TRANSACTION_REQUEST_BODY_SIZE + 1
  USER_ID_STRING_LENGTH = 49

  def initialize(@transaction_repository : Repositories::TransactionRepository, @auth_middleware : Middleware::AuthMiddleware)
    @prefix_length = "/api/v1/users/transactions".size
  end

  def handle_request(context : HTTP::Server::Context) : Nil
    # Get distinguishing path from resource string
    path = context.request.resource.unsafe_byte_slice(@prefix_length)

    # Call appropriate request handler
    case {context.request.method, path}
    when {"POST", "".to_slice}
      add_transaction(context)
    end
  end

  # Adds a transaction for the user.
  #
  # Method: POST
  # Path: /api/v1/users/transactions
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
end
