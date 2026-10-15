# frozen_string_literal: true

require 'securerandom'

module Broadcast
  # A file in a multipart/form-data request: the bytes, and the filename and
  # content type sent with them. Holding the bytes (not an IO) keeps a retry
  # safe: every attempt builds the body afresh.
  FilePart = Struct.new(:bytes, :filename, :content_type) do
    def inspect
      "#<Broadcast::FilePart #{filename} (#{content_type}, #{bytes.bytesize} bytes)>"
    end
    alias_method :to_s, :inspect
  end

  # Builds a multipart/form-data body by hand. Net::HTTP's set_form streams
  # the body at send time, which the debug logger and test doubles cannot see.
  module Multipart
    module_function

    # @param fields [Hash] values are FileParts or anything with #to_s; nil is left out
    # @return [Array(String, String)] the body (binary) and the Content-Type header
    def build(fields)
      boundary = "BroadcastRuby#{SecureRandom.hex(16)}"
      body = String.new(encoding: Encoding::BINARY)

      fields.each do |name, value|
        next if value.nil?

        body << "--#{boundary}\r\n"
        if value.is_a?(FilePart)
          body << "Content-Disposition: form-data; name=\"#{quote(name)}\"; filename=\"#{quote(value.filename)}\"\r\n"
          body << "Content-Type: #{value.content_type}\r\n\r\n"
          body << value.bytes.b
        else
          body << "Content-Disposition: form-data; name=\"#{quote(name)}\"\r\n\r\n"
          body << value.to_s.b
        end
        body << "\r\n"
      end
      body << "--#{boundary}--\r\n"

      [body, "multipart/form-data; boundary=#{boundary}"]
    end

    # A quote or a line break in a name would end the header early.
    def quote(value)
      value.to_s.gsub(/[\r\n]/, ' ').gsub('"', '%22').b
    end
  end
end
