require "http"
require "http/server"
require "db"
require "pg"
require "./utils/env"
require "./controllers/user_controller"
require "./repositories/user_repository"

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

# Initialize repositories
user_repository = Repositories::UserRepository.new(db)

# Initialize resource controllers
user_controller = Controllers::UserController.new(user_repository)

# Define server handling of requests
server = HTTP::Server.new do |context|
  if context.request.resource.starts_with?("/api/v1/users")
    user_controller.handle_request(context)
  end
end

# Start server
address = server.bind_tcp(host, port)
puts "Listening on port #{address.port}"
server.listen
