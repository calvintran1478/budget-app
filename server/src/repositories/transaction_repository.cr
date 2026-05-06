
struct Repositories::TransactionRepository
  def initialize(@db : DB::Database)
  end

  # Adds a user transaction to the database.
  def create(user_id : String, name : String, category : String, amount : Int32, currency : String) : String
    transaction_id = Random::Secure.urlsafe_base64()
    @db.exec "INSERT INTO transactions (user_id, transaction_id, name, category, amount, currency) VALUES ($1, $2, $3, $4, $5, $6)", user_id, transaction_id, name, category, amount, currency

    transaction_id
  end
end
