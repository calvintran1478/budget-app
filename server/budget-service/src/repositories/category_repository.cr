
struct Repositories::CategoryRepository
  def initialize(@db : DB::Database)
  end

  # Adds a user generated category to the database.
  #
  # Returns the newly created category_id.
  #
  # ```
  # category_repository.create(user_id, "Food and Drinks", 200, 0) # => category_id
  # ```
  def create(user_id : String, name : String, spending_limit : Int32, currency_index : Int32) : String
    category_id = Random::Secure.urlsafe_base64()
    @db.exec "INSERT INTO categories (user_id, category_id, name, spending_limit, currency_index) VALUES ($1, $2, $3, $4, $5)", user_id, category_id, name, spending_limit, currency_index

    category_id
  end

  # Lists categories from a single user and writes it to the given IO.
  #
  # ```
  # categories_repository.list(user_id, context.response.output)
  # ```
  def list(user_id : String, output : IO) : Nil
    @db.query("SELECT category_id, name, spending_limit, currency_index FROM categories WHERE user_id=$1", user_id) do |rs|
      rs.each do
        # Read row values
        category_id = rs.read(String)
        name = rs.read(String)
        spending_limit = rs.read(Int32)
        currency_index = rs.read(Int32)

        # Write row values to the provided IO
        output << category_id
        output.write_byte(name.bytesize.to_u8)
        output << name
        IO::ByteFormat::NetworkEndian.encode(spending_limit, output)
        output.write_byte(currency_index.to_u8)
      end
    end
  end

  # Updates a user generated category in the database.
  #
  # Fields set to nil are not updated. Returns whether the update was
  # successful. Assumes spending_limit is nil if and only if currency_index
  # is nil.
  #
  # ```
  # category_repository.update(user_id, category_id, "Transportation", nil, nil) # => true if category was found and updated
  # ```
  def update(user_id : String, category_id : String, name : String?, spending_limit : Int32?, currency_index : Int32?) : Bool
    query = <<-SQL
      UPDATE categories
      SET name = CASE WHEN $1 THEN $2 ELSE name END,
          spending_limit = CASE WHEN $5 THEN $6 ELSE spending_limit END,
          currency_index = CASE WHEN $7 THEN $8 ELSE currency_index END,
        WHERE user_id=$11 AND category_id=$12
    SQL
    result = @db.exec query, !name.nil?, name, !spending_limit.nil?, spending_limit, !currency_index.nil?, currency_index, user_id, category_id

    result.rows_affected == 1
  end

  # Deletes a user generated category from the database.
  #
  # Returns whether the deletion was successful.
  #
  # ```
  # category_repository.delete(user_id, category_id) # => true if category was found and deleted
  # ```
  def delete(user_id : String, category_id : String) : Bool
    result = @db.exec "DELETE FROM categories WHERE user_id=$1 AND category_id=$2", user_id, category_id

    result.rows_affected == 1
  end
end
