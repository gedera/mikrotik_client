# frozen_string_literal: true

module MikrotikClient
  module Middleware
    # Middleware that inspects the response and raises semantic exceptions.
    # Handles both HTTP status codes (REST) and MikroTik !trap attributes (Binary).
    #
    # @author Gabriel
    # @since 0.1.0
    class RaiseError < Base
      # Executes the request and then processes the outcome.
      #
      # @param env [Hash] The request environment.
      # @return [Hash]
      def call(env)
        @app.call(env)
        on_complete(env)
        env
      end

      private
# Inspects the response and raises the appropriate exception.
#
# @param env [Hash]
def on_complete(env)
  response = env[:response]
  return unless response.is_a?(Hash)

  # Handle tagged errors (from both Binary and HTTP adapters)
  if response["_error_type"]
    if response["_http_status"]
      handle_http_error(response)
    else
      handle_binary_error(response)
    end
  end
end

private

# Maps HTTP response data to MikrotikClient exceptions.
def handle_http_error(response)
  status = response["_http_status"].to_i
  message = response["detail"] || response["message"] || "HTTP Error"

  case status
  when 401      then raise AuthenticationError, "Invalid credentials for MikroTik"
  when 404      then raise NotFound, "Resource not found on MikroTik: #{message}"
  when 400      
    # MikroTik REST sometimes returns 400 for different semantic errors
    case
    when message.include?("no such command")
      raise NotFound, "MikroTik Error: #{message}"
    when message.include?("already have such entry")
      raise Conflict, "MikroTik Error: #{message}"
    else
      raise BadRequest, message
    end
  when 403, 406 then raise PermissionError, "Action not allowed on MikroTik"

  when 409      then raise Conflict, message
  when 422      then raise UnprocessableEntity, message
  when 500..599 then raise InternalServerError, message
  else
    raise Error, "MikroTik Error (#{status}): #{message}"
  end
end

      # Maps MikroTik Binary (!trap) errors to MikrotikClient exceptions.
      #
      # @param body [Hash] The trap sentence parsed as hash.
      def handle_binary_error(body)
        message = body["message"] || "Unknown error"
        category = body["category"] # "0": unknown, "1": busy, "2": failure, etc.

        # Semantic mapping based on common MikroTik error messages
        case
        when message.include?("no such command or directory"), message.include?("no such command prefix")
          raise NotFound, "MikroTik Error: #{message}"
        when message.include?("already have such entry")
          raise Conflict, "MikroTik Error: #{message}"
        when category == "2" # execution failure
          raise PermissionError, message
        when category == "3" # no such item
          raise NotFound, message
        else
          raise BadRequest, message
        end
      end

      # Cleans up the error body for clear exception traces.
      #
      # @param body [Hash, String, nil]
      # @return [String]
      def format_error_message(body)
        return "Unknown Error" if body.nil? || (body.respond_to?(:empty?) && body.empty?)
        return body if body.is_a?(String)
        
        # REST API v7 usually returns { "detail": "..." }
        body["detail"] || body["message"] || body.to_json
      end
    end
  end
end
