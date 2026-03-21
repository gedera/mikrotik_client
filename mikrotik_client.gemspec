# frozen_string_literal: true

require_relative "lib/mikrotik_client/version"

Gem::Specification.new do |spec|
  spec.name = "mikrotik_client"
  spec.version = MikrotikClient::VERSION
  spec.authors = ["Gabriel"]
  spec.email = ["gab.edera@gmail.com"]

  spec.summary = "A modern Ruby client for MikroTik RouterOS v6 and v7."
  spec.description = "Supports both the legacy API (v6/v7) and the modern REST API (v7+). Designed for Rails integration."
  spec.homepage = "https://github.com/gabriel/mikrotik_client"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "faraday-retry"
  spec.add_dependency "zeitwerk", "~> 2.6"
  spec.add_dependency "connection_pool", "~> 2.4"
  spec.add_dependency "activesupport", ">= 7.0"

  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "pry", "~> 0.14"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
