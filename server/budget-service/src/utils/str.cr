
module Utils::Str
  extend self

  # Initializes the given buffer as a string containing the same contents as the
  # provided bytes. The bytes are copied, leaving the original source unchanged.
  #
  # This can be used to have the internal buffer of the string be allocated on
  # the stack instead of the heap, reducing pressure placed on the garbage
  # collector.
  #
  # ```
  # require "../utils/str"
  #
  # buffer = uninitialized UInt8[18] # String::HEADER_SIZE + "hello".size + 1
  # my_string = Utils::Str.stringify("hello".to_unsafe, buffer.to_unsafe, 5) # => "hello"
  # ```
  def stringify(src_buffer : UInt8*, string_buffer : UInt8*, size : Int32) : String
    # Copy bytes over and terminate content with a null byte
    string_buffer = string_buffer.as(String)
    buffer = string_buffer.to_unsafe
    buffer.copy_from(src_buffer, size)
    buffer[size] = 0_u8

    # Initialize string header
    string_buffer.initialize_header(size, size)

    string_buffer
  end
end
