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
        last_name VARCHAR NOT NULL,
        sub VARCHAR
      );
    SQL
  )

  # Create category table
  db.exec(
    <<-SQL
      CREATE TABLE IF NOT EXISTS categories (
        category_id VARCHAR PRIMARY KEY,
        name VARCHAR NOT NULL,
        spending_limit INTEGER NOT NULL,
        currency_index INTEGER NOT NULL,
        user_id UUID,
        CONSTRAINT categories_user_id_fkey FOREIGN KEY(user_id) REFERENCES users(user_id)
          ON DELETE CASCADE
          ON UPDATE CASCADE,
        UNIQUE(user_id, name)
      )
    SQL
  )

  # Create transaction table
  db.exec(
    <<-SQL
      CREATE TABLE IF NOT EXISTS transactions (
        transaction_id VARCHAR PRIMARY KEY,
        name VARCHAR NOT NULL,
        category_id VARCHAR NOT NULL,
        amount INTEGER NOT NULL,
        currency_index INTEGER NOT NULL,
        date DATE NOT NULL DEFAULT NOW(),
        user_id UUID,
        CONSTRAINT transactions_user_id_fkey FOREIGN KEY(user_id) REFERENCES users(user_id)
          ON DELETE CASCADE
          ON UPDATE CASCADE,
        CONSTRAINT transactions_category_id_fkey FOREIGN KEY(category_id) REFERENCES categories(category_id)
          ON DELETE CASCADE
          ON UPDATE CASCADE
      )
    SQL
  )
end
