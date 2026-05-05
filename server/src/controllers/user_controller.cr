require "http/server"
require "../repositories/user_repository"
require "../schemas/user_schemas"
require "../utils/token"

# Controller for handling requests made to the user resource
struct Controllers::UserController
  include Schemas::UserSchemas

  @ACCESS_TOKEN_LIFESPAN : Int32
  @API_SECRET : String
  @BCRYPT_COST : Int32

  def initialize(@user_repository : Repositories::UserRepository)
    @prefix_length = "/api/v1/users".size

    @ACCESS_TOKEN_LIFESPAN = ENV["ACCESS_TOKEN_MINUTE_LIFESPAN"].to_i * 60
    @API_SECRET = ENV["API_SECRET"]
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
    when {"POST", "/login".to_slice}
      login_user(context)
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

  # Logs in the user by providing an access token they can use to authenticate
  # on protected endpoints.
  #
  # Method: POST
  # Path: /api/v1/users/login
  def login_user(context : HTTP::Server::Context) : Nil
    # Validate user input
    data = LoginRequest.from_context(context)
    return if data.nil?

    # Look up user in database
    user_id, password_hash = @user_repository.get_login_password(data.email)
    if user_id.nil?
      context.response.status = HTTP::Status::NOT_FOUND
      context.response.output << "User with email not found"
      return
    end

    # Verify user password
    password = Crypto::Bcrypt::Password.new(password_hash)
    unless password.verify(data.password)
      context.response.status = HTTP::Status::UNAUTHORIZED
      context.response.output << "Incorrect password"
      return
    end

    # Generate access token
    access_claims = Utils::Token::AccessClaims.new(user_id, Time.utc.to_unix + @ACCESS_TOKEN_LIFESPAN)

    # Send access token
    context.response.content_type = "text/plain"
    context.response.status = HTTP::Status::OK
    access_claims.encode(@API_SECRET, context.response.output)
  end
end
