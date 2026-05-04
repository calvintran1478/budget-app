require "http/server"
require "../repositories/user_repository"
require "../schemas/user_schemas"

# Controller for handling requests made to the user resource
struct Controllers::UserController
  include Schemas::UserSchemas

  @BCRYPT_COST : Int32

  def initialize(@user_repository : Repositories::UserRepository)
    @prefix_length = "/api/v1/users".size
    @BCRYPT_COST = ENV["BCRYPT_COST"].to_i
  end

  # Handles requests made to the /api/v1/users route by directing it to the correct handler
  def handle_request(context : HTTP::Server::Context) : Nil
    # Get distinguishing path from resource string
    path = context.request.resource.unsafe_byte_slice(@prefix_length)

    # Call appropriate request handler
    case {context.request.method, path}
    when {"POST", "".to_slice}
      register_user(context)
    end
  end

  # Registers an account for the user.
  #
  # Method: POST
  # Path: /api/v1/users
  def register_user(context : HTTP::Server::Context) : Nil
    # Validate user input
    data = RegisterRequest.from_context(context)
    return if data.nil?

    # Check if a user with the given email already exists
    if @user_repository.exists_with_email?(data.email)
      context.response.status = HTTP::Status::CONFLICT
      context.response.output << "User with email already exists"
      return
    end

    # Hash password
    hashed_password = Crypto::Bcrypt::Password.create(data.password, @BCRYPT_COST)

    # Register user into the database
    @user_repository.create(data.email, hashed_password, data.first_name, data.last_name)

    # Send success response
    context.response.content_type = "text/plain"
    context.response.status = HTTP::Status::CREATED
    context.response.output << RegisterResponse.new(data.email, data.first_name, data.last_name)
  end
end
