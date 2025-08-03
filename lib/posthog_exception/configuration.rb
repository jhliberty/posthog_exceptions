module PosthogException
  # Configuration class for PosthogException
  # Handles all configurable options for the gem
  class Configuration
    # PostHog API key
    attr_accessor :api_key

    # PostHog API URL
    attr_accessor :api_url

    # Current environment (development, production, etc.)
    attr_accessor :environment

    # Whether exception tracking is enabled
    attr_accessor :enabled

    # List of exception classes to ignore
    attr_accessor :ignored_exceptions

    # Initialize with default values
    def initialize
      @api_key = nil
      @api_url = 'https://us.i.posthog.com/i/v0/e/'
      @environment = defined?(Rails) ? Rails.env : ENV['RACK_ENV'] || ENV['RAILS_ENV'] || 'development'
      @enabled = @environment != 'test'
      @ignored_exceptions = ['ActiveRecord::RecordNotFound', 'ActionController::RoutingError']
    end
  end
end
