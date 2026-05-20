require "crypto/bcrypt/password"
require "uuid"

# Provides an interface for accessing the user table in the database
#
# All queries made to the user table should be made through a UserRepository
# object.
struct Repositories::UserRepository
  def initialize(@db : DB::Database)
  end

  # Returns whether a user with the given email exists.
  #
  # ```
  # user_repository.exists_with_email?("user@email.com") # => true if user@email exists in the database
  # ```
  def exists_with_email?(email : String) : Bool
    @db.query_one "SELECT EXISTS(SELECT 1 FROM users WHERE email=$1)", email, as: Bool
  end

  # Adds a user to the database.
  #
  # ```
  # user_repository.create("user@email.com", "hashed_password", "first_name", "last_name")
  # ```
  def create(email : String?, password : Crypto::Bcrypt::Password?, first_name : String, last_name : String, sub : String?) : UUID?

    if (sub.nil? && !password.nil? && !email.nil?) || (!sub.nil? && password.nil? && email.nil?)
      user_id = UUID.v4()
      @db.exec "INSERT INTO users (user_id, email, password, first_name, last_name, sub) VALUES ($1, $2, $3, $4, $5, $6)", user_id, email, password, first_name, last_name, sub
    else
      return 
    end

    user_id
  end

  # Returns the hashed password of a user along with their id.
  #
  # ```
  # user_repository.get_login_password("user@email.com") # => "user_id", "hashed_password"
  # ```
  def get_login_password(email : String) : Tuple(String, String)
    user_id, password = @db.query_one "SELECT user_id, password FROM users WHERE email=$1", email, as: { UUID, String }
    return user_id.to_s, password
  rescue DB::NoResultsError
    return "", ""
  end

  # Returns the the uuid of a user along with their id.
  #
  # ```
  # user_repository.get_login_password("user@email.com") # => "user_id", "hashed_password"
  # ```
  def get_uid(sub : String) : String
    user_id = @db.query_one "SELECT user_id FROM users WHERE sub=$1", sub, as: UUID
    return user_id.to_s
  rescue DB::NoResultsError
    return ""
  end
end
