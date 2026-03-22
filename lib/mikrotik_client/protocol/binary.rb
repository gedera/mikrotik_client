# frozen_string_literal: true

module MikrotikClient
  module Protocol
    # Low-level implementation of the MikroTik RouterOS Binary Protocol.
    # Handles length-prefixed encoding and sentence-based communication over a socket.
    #
    # @author Gabriel
    # @since 0.1.0
    class Binary
      # @param socket [IO] An open TCPSocket or OpenSSL::SSL::SSLSocket.
      def initialize(socket)
        @socket = socket
      end

      # Writes a complete sentence to the socket.
      # A sentence is a collection of words followed by an empty word (zero byte).
      #
      # @param words [Array<String>] The words to send (e.g., ["/ip/address/print", "=.proplist=.id,address"]).
      # @return [void]
      def write_sentence(words)
        words.each { |word| write_word(word) }
        @socket.write("\x00") # Sentence terminator
      end

      # Reads a complete sentence from the socket.
      #
      # @return [Array<String>] The words received in the sentence.
      def read_sentence
        words = []
        loop do
          word = read_word
          break if word.nil? # End of sentence

          words << word
        end
        words
      end

      private

      # Encodes and writes a single word to the socket.
      #
      # @param word [String] The word content.
      # @return [void]
      def write_word(word)
        @socket.write(encode_length(word.bytesize))
        @socket.write(word)
      end

      # Reads and decodes a single word from the socket.
      #
      # @return [String, nil] The decoded word, or nil if it's the sentence terminator.
      def read_word
        length = decode_length
        return nil if length.zero?

        @socket.read(length)
      end

      # Encodes the length of a word following MikroTik's variable-length scheme.
      #
      # @param len [Integer] The byte size of the word.
      # @return [String] The encoded length bytes.
      def encode_length(len)
        if len < 0x80
          [len].pack("C")
        elsif len < 0x4000
          [len | 0x8000].pack("n")
        elsif len < 0x200000
          [(len >> 16) | 0xC0, (len >> 8) & 0xFF, len & 0xFF].pack("C3")
        elsif len < 0x10000000
          [len | 0xE0000000].pack("N")
        else
          "\xF0" + [len].pack("N")
        end
      end

      # Decodes the length of the next word from the socket.
      #
      # @return [Integer] The decoded length.
      def decode_length
        b1 = @socket.read(1).unpack1("C")

        if (b1 & 0x80).zero?
          b1
        elsif (b1 & 0x40).zero?
          ((b1 & 0x3F) << 8) | @socket.read(1).unpack1("C")
        elsif (b1 & 0x20).zero?
          ((b1 & 0x1F) << 16) | @socket.read(2).unpack1("n")
        elsif (b1 & 0x10).zero?
          bytes = @socket.read(3).unpack("C3")
          ((b1 & 0x0F) << 24) | (bytes[0] << 16) | (bytes[1] << 8) | bytes[2]
        elsif b1 == 0xF0
          @socket.read(4).unpack1("N")
        else
          raise MikrotikClient::Error, "Invalid word length prefix: 0x#{b1.to_s(16)}"
        end
      end
    end
  end
end
