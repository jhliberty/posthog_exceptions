module PosthogExceptions
  # Controller integration methods for Rails applications
  module ControllerMethods
    # Include these methods in ActionController::Base
    def self.included(base)
      base.rescue_from StandardError do |exception|
        posthog_report_exception(exception)
        raise exception # Re-raise to allow normal error handling
      end
    end

    private

    # Report an exception to PostHog with controller context
    #
    # @param exception [Exception] the exception to report
    # @param custom_context [Hash] additional context to include
    # @return [Boolean] whether the exception was reported successfully
    def posthog_report_exception(exception, custom_context = {})
      # Skip if this exception should be ignored
      return false if PosthogExceptions.configuration.ignored_exceptions.include?(exception.class.name)

      # Add controller context
      context = {
        controller: controller_name,
        action: action_name,
        params: if params.respond_to?(:to_unsafe_h)
                  params.to_unsafe_h.except('password',
                                            'password_confirmation')
                else
                  params.except(
                    'password', 'password_confirmation'
                  )
                end,
        url: request.url,
        method: request.method,
        format: request.format.to_s,
        remote_ip: request.remote_ip,
        user_agent: request.user_agent
      }

      # Add user context if available
      if current_user = fetch_current_user
        context[:user_id] = current_user.respond_to?(:analytics_uuid) ? current_user.analytics_uuid : current_user.id
        context[:user_email] = current_user.email if current_user.respond_to?(:email)
      end

      # Merge custom context
      context.merge!(custom_context) if custom_context.is_a?(Hash)

      # Report to PostHog asynchronously
      PosthogExceptions.notify_async(exception, context)
    end

    def fetch_current_user
      if respond_to?(:current_user)
        current_user
      elsif defined?(Current) && Current.respond_to?(:user)
        Current.user
      end
    end
  end
end
