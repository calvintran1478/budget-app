
struct Repositories::TransactionRepository
  def initialize(@db : DB::Database)
  end

  # Adds a transaction to the database.
  #
  # Returns the newly created transaction_id.
  #
  # ```
  # transaction_repository.create(user_id, "Coffee", category_id, 200, 0) # => transaction_id
  # ```
  def create(user_id : String, name : String, category_id : String, amount : Int32, currency_index : Int32) : String
    transaction_id = Random::Secure.urlsafe_base64()
    @db.exec "INSERT INTO transactions (user_id, transaction_id, name, category_id, amount, currency_index) VALUES ($1, $2, $3, $4, $5, $6)", user_id, transaction_id, name, category_id, amount, currency_index

    transaction_id
  end

  # Lists transactions (or total value of transactions) from a single user and
  # writes it to the given IO.
  #
  # ```
  # transaction_repository.list(user_id, context.response.output)
  # ```
  def list(user_id : String, start_time : Time, end_time : Time, sum : Bool, output : IO) : Nil
    if sum
      query = <<-SQL
        SELECT c.name, SUM(t.amount)
        FROM transactions t INNER JOIN categories c ON t.category_id = c.category_id
        WHERE t.user_id = $1 AND t.date BETWEEN $2 AND $3
        GROUP BY c.name
      SQL

      @db.query(query, user_id, start_time, end_time) do |rs|
        rs.each do
          # Read row values
          category = rs.read(String)
          sum_value = rs.read(Int64)

          output.write_byte(category.bytesize.to_u8)
          output << category
          IO::ByteFormat::NetworkEndian.encode(sum_value, output)
        end
      end
    else
      query = <<-SQL
        SELECT t.transaction_id, t.date, t.amount, t.name, c.name, t.currency_index
        FROM transactions t INNER JOIN categories c ON t.category_id = c.category_id
        WHERE t.user_id=$1 AND t.date BETWEEN $2 AND $3 ORDER BY date DESC
      SQL

      @db.query(query, user_id, start_time, end_time) do |rs|
        rs.each do
          # Read row values
          transaction_id = rs.read(String)
          date = rs.read(Time)
          amount = rs.read(Int32)
          name = rs.read(String)
          category = rs.read(String)
          currency_index = rs.read(Int32)

          # Write row values to the provided IO
          output << transaction_id
          date.to_s(output, "%b %d, %Y")
          IO::ByteFormat::NetworkEndian.encode(amount, output)
          output.write_byte(name.bytesize.to_u8)
          output << name
          output.write_byte(category.bytesize.to_u8)
          output << category
          output.write_byte(currency_index.to_u8)
        end
      end
    end
  end

  # Updates a transaction in the database.
  #
  # Fields set to nil are not updated. Returns whether the update was
  # successful.
  #
  # ```
  # transaction_repository.update(user_id, transaction_id, nil, category_id, 400, nil, nil) # => true if transaction was found and updated
  # ```
  def update(user_id : String, transaction_id : String, name : String?, category_id : String?, amount : Int32?, currency_index : Int32?, date : Time?) : Bool
    query = <<-SQL
      UPDATE transactions
      SET name = CASE WHEN $1 THEN $2 ELSE name END,
          category_id = CASE WHEN $3 THEN $4 ELSE category_id END,
          amount = CASE WHEN $5 THEN $6 ELSE amount END,
          currency_index = CASE WHEN $7 THEN $8 ELSE currency_index END,
          date = CASE WHEN $9 THEN $10 ELSE date END
        WHERE user_id=$11 AND transaction_id=$12
    SQL
    result = @db.exec query, !name.nil?, name, !category_id.nil?, category_id, !amount.nil?, amount, !currency_index.nil?, currency_index, !date.nil?, date, user_id, transaction_id

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
