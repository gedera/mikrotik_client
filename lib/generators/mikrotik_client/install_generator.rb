# frozen_string_literal: true

require "rails/generators/base"

module MikrotikClient
  module Generators
    # Generator to install MikrotikClient configuration.
    # Run this generator with `rails generate mikrotik_client:install`.
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Creates a MikrotikClient initializer for your application."

      def copy_initializer
        template "mikrotik_client.rb", "config/initializers/mikrotik_client.rb"
      end

      def show_readme
        readme "README" if File.exist?("README")
      end
    end
  end
end
