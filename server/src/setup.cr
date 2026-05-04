require "db"
require "pg"
require "./utils/env"

# Load environment
Utils::Env.load_env()

# Connect to database and create tables
DB.connect ENV["DB_CONN"] do |db|
  # Create user table
  db.exec(
    <<-SQL
      CREATE TABLE IF NOT EXISTS users (
        user_id UUID PRIMARY KEY,
        email VARCHAR UNIQUE NOT NULL,
        password VARCHAR NOT NULL,
        first_name VARCHAR NOT NULL,
        last_name VARCHAR NOT NULL
      );
    SQL
  )
end
