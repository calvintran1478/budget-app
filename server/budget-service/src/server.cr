require "http"
require "http/server"
require "db"
require "pg"
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

# Load environment
Utils::Env.load_env() if host == "127.0.0.1"

# Connect to database
db = DB.open(ENV["DB_CONN"])

# Initialize middleware
auth_middleware = Middleware::AuthMiddleware.new(ENV["API_SECRET"])

# Initialize repositories
user_repository = Repositories::UserRepository.new(db)
transaction_repository = Repositories::TransactionRepository.new(db)

# Initialize resource controllers
user_controller = Controllers::UserController.new(user_repository)
transaction_controller = Controllers::TransactionController.new(transaction_repository, auth_middleware)

# Define server handling of requests
server = HTTP::Server.new do |context|
  # Handle CORS
  context.response.headers["Access-Control-Allow-Origin"] = "http://localhost:8081"
  context.response.headers["Access-Control-Allow-Methods"] = "POST,GET,PATCH,DELETE"
  context.response.headers["Access-Control-Allow-Headers"] = "Content-Type,Authorization"
  if context.request.method == "OPTIONS"
    context.response.status = HTTP::Status::OK
    next
  end

  if context.request.resource.starts_with?("/api/v1/users")
    user_controller.handle_request(context)
  elsif context.request.resource.starts_with?("/api/v1/transactions")
    transaction_controller.handle_request(context)
  else
    context.response.status = HTTP::Status::NOT_FOUND
  end
end

# Start server
address = server.bind_tcp(host, port)
puts "Listening on port #{address.port}"
server.listen
