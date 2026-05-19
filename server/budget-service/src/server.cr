require "http"
require "http/server"
require "db"
require "pg"
require "redis"
require "./utils/env"
require "./controllers/user_controller"
require "./controllers/transaction_controller"
require "./repositories/user_repository"
require "./repositories/transaction_repository"
require "./middleware/auth_middleware"

# Read CLI arguments
case ARGV.size
when 0 then host, port = "127.0.0.1", 8080
when 2 then host, port = ARGV[0], ARGV[1].to_i
else
  puts "Error: Unexpected number of arguments"
  puts "Usage: ./server"
  puts "Usage: ./server [host] [port]"
  exit 1
end

# Create google auth client
OAUTH_HOST = "google.com"
CLIENT_ID     = ENV["GOOGLE_CLIENT_ID"]
CLIENT_SECRET = ENV["GOOGLE_CLIENT_SECRET"]
client = OAuth2::Client.new(
  "accounts.google.com",
  CLIENT_ID,
  CLIENT_SECRET,
  authorize_uri: "/o/oauth2/v2/auth",
  token_uri: "https://oauth2.googleapis.com/token", 
  redirect_uri: "http://localhost:8080/google-callback"
)

# Load environment
Utils::Env.load_env() if host == "127.0.0.1"

# Connect to database
db = DB.open(ENV["DB_CONN"])
auth_db = Redis::PooledClient.new(url: ENV["AUTH_DB_CONN"])

# Initialize middleware
auth_middleware = Middleware::AuthMiddleware.new(ENV["API_SECRET"])

# Initialize repositories
user_repository = Repositories::UserRepository.new(db)
transaction_repository = Repositories::TransactionRepository.new(db)

# Initialize resource controllers
user_controller = Controllers::UserController.new(user_repository, auth_db)
transaction_controller = Controllers::TransactionController.new(transaction_repository, auth_middleware)

# Define server handling of requests
server = HTTP::Server.new do |context|
  # Handle CORS
  origin = context.request.headers["Origin"]?
  if origin && {"http://localhost:8081","http://localhost:5173"}.includes?(origin)
    context.response.headers["Access-Control-Allow-Origin"] = origin
    context.response.headers["Access-Control-Allow-Methods"] = "POST,GET,PATCH,DELETE"
    context.response.headers["Access-Control-Allow-Headers"] = "Content-Type,Authorization"
    context.response.headers["Access-Control-Allow-Credentials"] = "true"
  end
  if context.request.method == "OPTIONS"
    context.response.status = HTTP::Status::OK
    next
  end

  # Match resource path
  if context.request.resource.starts_with?("/api/v1/users")
    user_controller.handle_request(context)
  elsif context.request.resource.starts_with?("/api/v1/transactions")
    transaction_controller.handle_request(context)

  # Google Oauth logic
  elsif context.request.path == "/google-login"
    # Redirect user to provider
    authorize_url = client.get_authorize_uri(scope: "openid email profile")
    context.response.status_code = 302
    context.response.headers["Location"] = authorize_url.to_s
  elsif context.request.path.starts_with?("/google-callback")
    p "hi"
    code = context.request.query_params["code"]?
    if code.nil?
      context.response.status_code = 400
      context.response.print "Missing code"
      next
    end
    begin
      context.response.status_code = 400
      token = client.get_access_token_using_authorization_code(code)
      if token
        p "hi2"
        user_controller.google_login(context, token)
      end
    rescue ex
      context.response.status_code = 500
      context.response.print "Error: #{ex.message}"
    end

  else
    context.response.status = HTTP::Status::NOT_FOUND
  end
end
# Start server
address = server.bind_tcp(host, port)
puts "Listening on port #{address.port}"
server.listen
