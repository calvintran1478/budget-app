require "../schemas/category_schemas"

struct Controllers::CategoryController
  include Schemas::CategorySchemas

  ADD_CATEGORY_REQUEST_BUFFER_SIZE = 126 # MAX_ADD_CATEGORY_REQUEST_BODY_SIZE + 1
  USER_ID_STRING_LENGTH = 49
  CATEGORY_ID_LENGTH = 22

  def initialize(@category_repository : Repositories::CategoryRepository, @auth_middleware : Middleware::AuthMiddleware)
    @prefix_length = "/api/v1/categories".size
  end

  def handle_request(context : HTTP::Server::Context) : Nil
    # Get distinguishing path from resource string
    path = context.request.resource.unsafe_byte_slice(@prefix_length)

    # Call appropriate request handler
    case {context.request.method, path}
    when {"POST", "".to_slice}
      add_category(context)
    when {"GET", "".to_slice}
      get_categories(context)
    when {"PATCH", _}
      if path.size == 1 + CATEGORY_ID_LENGTH && path.unsafe_fetch(0) == '/'.ord
        update_category(context, String.new(path.to_unsafe + 1, CATEGORY_ID_LENGTH))
      else
        context.response.status = HTTP::Status::NOT_FOUND
      end
    when {"DELETE", _}
      if path.size == 1 + CATEGORY_ID_LENGTH && path.unsafe_fetch(0) == '/'.ord
        delete_category(context, String.new(path.to_unsafe + 1, CATEGORY_ID_LENGTH))
      else
        context.response.status = HTTP::Status::NOT_FOUND
      end
    else
      context.response.status = HTTP::Status::NOT_FOUND
    end
  end

  # Adds a category for the user.
  #
  # Method: POST
  # Path: /api/v1/categories
  def add_category(context : HTTP::Server::Context) : Nil
    # Get user
    user_id_buffer = uninitialized UInt8[USER_ID_STRING_LENGTH]
    user_id = @auth_middleware.get_user(context, user_id_buffer.to_unsafe)
    return if user_id.nil?

    # Validate user input
    add_category_request_buffer = uninitialized UInt8[ADD_CATEGORY_REQUEST_BUFFER_SIZE]
    data = AddCategoryRequest.from_context(context, add_category_request_buffer.to_unsafe)
    return if data.nil?

    # Add category
    category_id = @category_repository.create(user_id, data.name, data.spending_limit, data.currency_index)

    # Send success response
    context.response.content_type = "text/plain"
    context.response.status = HTTP::Status::CREATED
    context.response.output << category_id
  end

  # Retreives categories for the user.
  #
  # Method: GET
  # Path: /api/v1/categories
  def get_categories(context : HTTP::Server::Context) : Nil
    # Get user
    user_id_buffer = uninitialized UInt8[USER_ID_STRING_LENGTH]
    user_id = @auth_middleware.get_user(context, user_id_buffer.to_unsafe)
    return if user_id.nil?

    # Send categories
    context.response.content_type = "application/octect-stream"
    context.response.status = HTTP::Status::OK
    @category_repository.list(user_id, context.response.output)
  end

  # Updates a category for the user.
  #
  # Method: PATCH
  # Path: /api/v1/categories/{category_id}
  def update_category(context : HTTP::Server::Context, category_id : String) : Nil
    # Get user
    user_id_buffer = uninitialized UInt8[USER_ID_STRING_LENGTH]
    user_id = @auth_middleware.get_user(context, user_id_buffer.to_unsafe)
    return if user_id.nil?

    # Validate user input
    data = UpdateCategoryRequest.from_context(context)
    return if data.nil?

    # Update category
    unless @category_repository.update(user_id, category_id, data.name, data.spending_limit, data.currency_index)
      context.response.status = HTTP::Status::NOT_FOUND
      context.response.output << "Category not found"
      return
    end

    # Send success response
    context.response.status = HTTP::Status::NO_CONTENT
  end

  # Deletes a category for the user.
  #
  # Method: Delete
  # Path: /api/v1/categories/{category_id}
  def delete_category(context : HTTP::Server::Context, category_id : String) : Nil
    # Get user
    user_id_buffer = uninitialized UInt8[USER_ID_STRING_LENGTH]
    user_id = @auth_middleware.get_user(context, user_id_buffer.to_unsafe)
    return if user_id.nil?

    # Delete category
    unless @category_repository.delete(user_id, category_id)
      context.response.status = HTTP::Status::NOT_FOUND
      context.response.output << "Category not found"
      return
    end

    # Send success response
    context.response.status = HTTP::Status::NO_CONTENT
  end
end
