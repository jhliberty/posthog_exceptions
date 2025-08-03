require 'net/http'
require 'uri'
require 'json'
require 'securerandom'
require 'digest'

require 'posthog_exception/version'
require 'posthog_exception/configuration'
require 'posthog_exception/middleware'
require 'posthog_exception/controller_methods'
require 'posthog_exception/railtie' if defined?(Rails)

module PosthogException
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def notify(exception, context = {})
      return false unless configuration.enabled
      return false if exception.nil?
      return false if configuration.ignored_exceptions.include?(exception.class.name)

      # Generate a unique fingerprint for this exception
      fingerprint = generate_fingerprint(exception, context)

      # Prepare the exception details
      exception_data = {
        type: exception.class.name,
        value: exception.message,
        mechanism: {
          handled: true,
          synthetic: false
        },
        stacktrace: {
          type: 'resolved',
          frames: parse_backtrace(exception.backtrace || [])
        }
      }

      # Prepare the properties
      properties = {
        distinct_id: context[:user_id] || context[:distinct_id] || 'anonymous',
        '$exception_list': [exception_data],
        '$exception_fingerprint': fingerprint,
        environment: configuration.environment
      }

      # Merge additional context
      properties.merge!(context.except(:user_id, :distinct_id)) if context.is_a?(Hash)

      # Send to PostHog
      send_to_posthog(properties)
    end

    def notify_async(exception, context = {})
      if defined?(Rails) && Rails.application && defined?(ActiveJob)
        PosthogException::PosthogExceptionJob.perform_later(
          exception_class: exception.class.name,
          message: exception.message,
          backtrace: exception.backtrace,
          context: context
        )
      else
        notify(exception, context)
      end
    end

    private

    def generate_fingerprint(exception, context = {})
      # Create a fingerprint based on exception class, message, and first few lines of backtrace
      components = [
        exception.class.name,
        exception.message,
        exception.backtrace&.first(3)
      ]

      # Add context values that might help identify unique errors
      components << context[:action] if context[:action]
      components << context[:controller] if context[:controller]

      # Create SHA256 hash of these components
      Digest::SHA256.hexdigest(components.flatten.compact.join('|'))
    end

    def parse_backtrace(backtrace)
      backtrace.first(50).map do |line|
        if line =~ /^(.+?):(\d+)(?::in `(.+)')?$/
          file = ::Regexp.last_match(1)
          line_num = ::Regexp.last_match(2).to_i
          method = ::Regexp.last_match(3)
          {
            raw_id: Digest::SHA512.hexdigest("#{file}:#{line_num}:#{method}"),
            filename: file,
            lineno: line_num,
            function: method || 'unknown',
            in_app: file.start_with?(defined?(Rails) ? Rails.root.to_s : Dir.pwd),
            resolved_name: method || 'unknown',
            lang: 'ruby',
            resolved: true
          }
        else
          {
            raw_id: Digest::SHA512.hexdigest(line),
            filename: line,
            in_app: false,
            lang: 'ruby'
          }
        end
      end
    end

    def send_to_posthog(properties)
      return false unless configuration.api_key

      uri = URI.parse(configuration.api_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true if uri.scheme == 'https'

      request = Net::HTTP::Post.new(uri.request_uri)
      request['Content-Type'] = 'application/json'

      payload = {
        api_key: configuration.api_key,
        event: '$exception',
        properties: properties
      }

      request.body = payload.to_json

      begin
        response = http.request(request)
        response.code == '200'
      rescue StandardError => e
        if defined?(Rails) && Rails.logger
          Rails.logger.error("Failed to send exception to PostHog: #{e.message}")
        else
          warn("Failed to send exception to PostHog: #{e.message}")
        end
        false
      end
    end
  end
end

# Load the job class if ActiveJob is available
require 'posthog_exception/job' if defined?(ActiveJob)
