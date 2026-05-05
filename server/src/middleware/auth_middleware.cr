
# Middleware for authenticating user requests made to a protected endpoint
class Middleware::AuthMiddleware
  EXPECTED_AUTH_HEADER_SIZE = 97

  def initialize(@API_SECRET : String)
  end

  # Retreives the user id from the given HTTP server context.
  #
  # If authentication fails for any reason this function returns nil and writes
  # a status code of 401 to the response header.
  #
  # ```
  # user_id = @auth_middleware.get_user(context)
  # ```
  def get_user(context : HTTP::Server::Context) : (String | Nil)
    # Check that the authorization header is included
    auth_header = context.request.headers["Authorization"]?
    if auth_header.nil? || auth_header.size != EXPECTED_AUTH_HEADER_SIZE
      context.response.status = HTTP::Status::UNAUTHORIZED
      return
    end

    # Extract access token
    unless auth_header.starts_with?("Bearer ")
      context.response.status = HTTP::Status::UNAUTHORIZED
      return
    end

    # Parse access token and get user id
    user_id = Utils::Token::AccessClaims.decode(auth_header.to_unsafe + 7, @API_SECRET)
    if user_id.nil?
      context.response.status = HTTP::Status::UNAUTHORIZED
      return
    end

    user_id
  end
end
