module PosthogException
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      @app.call(env)
    # rubocop:disable Lint/RescueException
    rescue Exception => e
      # Only report if it's not in the ignored exceptions list
      unless PosthogException.configuration.ignored_exceptions.include?(e.class.name)
        # Create a request object to extract information
        request = if defined?(ActionDispatch::Request)
                    ActionDispatch::Request.new(env)
                  else
                    Rack::Request.new(env)
                  end

        # Get user information if available
        user_id = nil
        if defined?(Warden) && env['warden']&.user
          user = env['warden'].user
          user_id = user.respond_to?(:analytics_uuid) ? user.analytics_uuid : (user&.id || nil)
        end

        # Create context with request details
        context = {
          distinct_id: user_id,
          url: request.url,
          controller: env['action_controller.instance']&.controller_name,
          action: env['action_controller.instance']&.action_name,
          params: request.respond_to?(:filtered_parameters) ? request.filtered_parameters : request.params,
          request_id: request.respond_to?(:request_id) ? request.request_id : nil,
          remote_ip: request.ip,
          user_agent: request.user_agent,
          http_method: request.request_method,
          http_host: request.host,
          path: request.path
        }.compact

        # Notify PostHog
        PosthogException.notify(e, context)
      end

      # Re-raise the exception
      raise e
      # rubocop:enable Lint/RescueException
    end
  end
end
