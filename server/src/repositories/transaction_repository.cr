
struct Repositories::TransactionRepository
  def initialize(@db : DB::Database)
  end

  # Adds a transaction to the database.
  #
  # Returns the newly created transaction_id.
  #
  # ```
  # transaction_repository.create(user_id, "Coffee", "Food and Drinks", 200, "CAD") # => transaction_id
  # ```
  def create(user_id : String, name : String, category : String, amount : Int32, currency : String) : String
    transaction_id = Random::Secure.urlsafe_base64()
    @db.exec "INSERT INTO transactions (user_id, transaction_id, name, category, amount, currency) VALUES ($1, $2, $3, $4, $5, $6)", user_id, transaction_id, name, category, amount, currency

    transaction_id
  end

  # Lists transactions from a single user and writes it to the given IO.
  #
  # ```
  # transaction_repository.list(user_id, context.response.output)
  # ```
  def list(user_id : String, output : IO) : Nil
    @db.query("SELECT transaction_id, date, amount, name, category, currency FROM transactions WHERE user_id=$1", user_id) do |rs|
      rs.each do
        # Read row values
        transaction_id = rs.read(String)
        date = rs.read(Time)
        amount = rs.read(Int32)
        name = rs.read(String)
        category = rs.read(String)
        currency = rs.read(String)

        # Write row values to the provided IO
        output << transaction_id
        date.to_s(output, "%Y-%m-%d")
        IO::ByteFormat::NetworkEndian.encode(amount, output)
        output.write_byte(name.bytesize.to_u8)
        output << name
        output.write_byte(category.bytesize.to_u8)
        output << category
        output.write_byte(currency.bytesize.to_u8)
        output << currency
      end
    end
  end

  # Updates a transaction in the database.
  #
  # Fields set to nil are not updated. Returns whether the update was
  # successful.
  #
  # ```
  # transaction_repository.update(user_id, transaction_id, nil, "Transportation", 400, nil, nil) # => true if transaction was found and updated
  # ```
  def update(user_id : String, transaction_id : String, name : String?, category : String?, amount : Int32?, currency : String?, date : Time?) : Bool
    query = <<-SQL
      UPDATE transactions
      SET name = CASE WHEN $1 THEN $2 ELSE name END,
          category = CASE WHEN $3 THEN $4 ELSE category END,
          amount = CASE WHEN $5 THEN $6 ELSE amount END,
          currency = CASE WHEN $7 THEN $8 ELSE currency END,
          date = CASE WHEN $9 THEN $10 ELSE date END
        WHERE user_id=$11 AND transaction_id=$12
    SQL
    result = @db.exec query, !name.nil?, name, !category.nil?, category, !amount.nil?, amount, !currency.nil?, currency, !date.nil?, date, user_id, transaction_id

    result.rows_affected == 1
  end

  # Deletes a transaction from the database.
  #
  # Returns whether the deletion was successful.
  #
  # ```
  # transaction_repository.delete(user_id, transaction_id) # => true if transaction was found and deleted
  # ```
  def delete(user_id : String, transaction_id : String) : Bool
    result = @db.exec "DELETE FROM transactions WHERE user_id=$1 AND transaction_id=$2", user_id, transaction_id

    result.rows_affected == 1
  end
end
