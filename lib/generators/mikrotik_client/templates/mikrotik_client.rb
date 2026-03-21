# frozen_string_literal: true

MikrotikClient.configure do |config|
  # The logger instance to use (default: Rails.logger if available, or STDOUT)
  config.logger = defined?(Rails) ? Rails.logger : Logger.new($stdout)

  # The logging level (default: Logger::INFO)
  config.log_level = Logger::INFO

  # Network timeouts in seconds
  config.connect_timeout = 5
  config.read_timeout = 10

  # Connection Pool settings
  # pool_size: number of persistent connections per router
  config.pool_size = 5
  # pool_timeout: seconds to wait for a connection to become available
  config.pool_timeout = 5

  # Inactivity timeout: seconds before an idle connection pool is closed and removed.
  # Set this based on how often you perform tasks on your MikroTiks.
  config.idle_timeout = 300 # 5 minutes
end
