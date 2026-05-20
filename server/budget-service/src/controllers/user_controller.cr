require "http/server"
require "../repositories/user_repository"
require "../schemas/user_schemas"
require "../utils/token"
require "oauth2"

# Controller for handling requests made to the user resource
struct Controllers::UserController
  include Schemas::UserSchemas

  @ACCESS_TOKEN_LIFESPAN : Int32
  @API_SECRET : String
  @BCRYPT_COST : Int32
  @REFRESH_TOKEN_LIFESPAN : Int32

  def initialize(@user_repository : Repositories::UserRepository, @auth_db : Redis::PooledClient)
    @prefix_length = "/api/v1/users".size

    @ACCESS_TOKEN_LIFESPAN = ENV["ACCESS_TOKEN_MINUTE_LIFESPAN"].to_i * 60
    @API_SECRET = ENV["API_SECRET"]
    @BCRYPT_COST = ENV["BCRYPT_COST"].to_i
    @REFRESH_TOKEN_LIFESPAN = ENV["REFRESH_TOKEN_HOUR_LIFESPAN"].to_i * 3600
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
    when {"GET", "/token".to_slice}
      refresh_token(context)
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
    @user_repository.create(data.email, hashed_password, data.first_name, data.last_name, nil)

    # Send success response
    context.response.status = HTTP::Status::CREATED
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

    # Start token family
    token_family_id = UUID.v4().to_s
    @auth_db.set(token_family_id, 1, ex: @REFRESH_TOKEN_LIFESPAN)

    # Generate access token and refresh token pair
    access_claims = Utils::Token::AccessClaims.new(user_id, Time.utc.to_unix + @ACCESS_TOKEN_LIFESPAN)
    refresh_claims = Utils::Token::RefreshClaims.new(user_id, token_family_id, 1, Time.utc.to_unix + @REFRESH_TOKEN_LIFESPAN)

    # Set http-only cookie containing refresh token
    context.response.cookies << HTTP::Cookie.new(
      name: "refresh-token",
      value: refresh_claims.encode(@API_SECRET),
      max_age: Time::Span.new(seconds: @REFRESH_TOKEN_LIFESPAN),
      http_only: true,
      secure: true,
      samesite: HTTP::Cookie::SameSite::Strict
    )

    # Send access token
    context.response.content_type = "text/plain"
    context.response.status = HTTP::Status::OK
    access_claims.encode(@API_SECRET, context.response.output)
  end

  # Returns a new refresh token access token pair the user can use to
  # authenticate on protected endpoints. The user must have a valid refresh
  # token cookie.
  #
  # Method: GET
  # Path: /api/v1/users/token
  def refresh_token(context : HTTP::Server::Context) : Nil
    #Parse claims if token is not expired
    refresh_token_cookie = context.request.cookies["refresh-token"]?
    if refresh_token_cookie.nil? || refresh_token_cookie.value.size != 132
      context.response.status = HTTP::Status::UNAUTHORIZED
      return
    end

    # Decode payload
    payload = Utils::Token::RefreshClaims.decode(refresh_token_cookie.value.to_unsafe, @API_SECRET)
    if payload.nil?
      context.response.status = HTTP::Status::UNAUTHORIZED
      return
    end
    # Validate sequence number
    expected_sequence_number = @auth_db.get(payload.token_family_id)
    if expected_sequence_number.nil?
      context.response.status = HTTP::Status::UNAUTHORIZED
      return
    elsif payload.sequence_number != expected_sequence_number.to_i
      @auth_db.del(payload.token_family_id)
      context.response.status = HTTP::Status::UNAUTHORIZED
      return
    end

    # Update sequence number to reflect new token in the token family
    @auth_db.set(payload.token_family_id, payload.sequence_number + 1, ex: @REFRESH_TOKEN_LIFESPAN)

    # Generate access token and refresh token pair
    access_claims = Utils::Token::AccessClaims.new(payload.user_id, Time.utc.to_unix + @ACCESS_TOKEN_LIFESPAN)
    refresh_claims = Utils::Token::RefreshClaims.new(payload.user_id, payload.token_family_id, payload.sequence_number + 1, Time.utc.to_unix + @REFRESH_TOKEN_LIFESPAN)

    # Set http-only cookie containing refresh token
    context.response.cookies << HTTP::Cookie.new(
      name: "refresh-token",
      value: refresh_claims.encode(@API_SECRET),
      max_age: Time::Span.new(seconds: @REFRESH_TOKEN_LIFESPAN),
      http_only: true,
      secure: true,
      samesite: HTTP::Cookie::SameSite::Strict
    )

    # Send access token
    context.response.content_type = "text/plain"
    context.response.status = HTTP::Status::OK
    access_claims.encode(@API_SECRET, context.response.output)
  end

  # Logs in the user with their google auth code, provides an access token
  # they can use to authenticate on protected endpoints.
  #
  # Method: POST
  # Path: /api/v1/users/login
  def google_login(context : HTTP::Server::Context, token : OAuth2::AccessToken) : Nil

    #token = client.get_access_token_using_authorization_code(auth_code)
    if extra = token.extra
      if id_token = extra["id_token"]?
        parts = id_token.split(".")
        padded = parts[1] + "=" * ((4 - parts[1].size % 4) % 4)
        payload = JSON.parse(Base64.decode_string(padded))
        
        sub = payload["sub"].as_s

        # get uid 
        user_id = @user_repository.get_uid(sub)
        # create account if uid is nil
        if user_id == ""
          first_name = payload["given_name"]?.try(&.as_s)
          last_name = payload["family_name"]?.try(&.as_s) 
          if first_name && last_name
            user_id = @user_repository.create(nil, nil, first_name, last_name, sub)
          end
        end
        # Generate access token
        if user_id
          # Start token family
          token_family_id = UUID.v4().to_s
          @auth_db.set(token_family_id, 1, ex: @REFRESH_TOKEN_LIFESPAN)

          # Generate access and refresh tokens
          access_claims = Utils::Token::AccessClaims.new(user_id.as(String), Time.utc.to_unix + @ACCESS_TOKEN_LIFESPAN)
          refresh_claims = Utils::Token::RefreshClaims.new(user_id.as(String), token_family_id, 1, Time.utc.to_unix + @REFRESH_TOKEN_LIFESPAN)

          # Set refresh token cookie
          context.response.cookies << HTTP::Cookie.new(
            name: "refresh-token",
            value: refresh_claims.encode(@API_SECRET),
            max_age: Time::Span.new(seconds: @REFRESH_TOKEN_LIFESPAN),
            http_only: true,
            secure: true,
            samesite: HTTP::Cookie::SameSite::Strict
          )

          # Redirect to frontend with access token in query param
          access_token = access_claims.encode(@API_SECRET)
          context.response.status_code = 302
          context.response.headers["Location"] = "http://localhost:5173/auth/callback"
        end
      end
    end
  end
end
