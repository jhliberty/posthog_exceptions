module PosthogExceptions
  # Background Job to handle async exception tracking
  class PosthogExceptionsJob < ActiveJob::Base
    queue_as :default

    # Process the exception asynchronously
    #
    # @param exception_class [String] the class name of the exception
    # @param message [String] the exception message
    # @param backtrace [Array<String>] the exception backtrace
    # @param context [Hash] additional context for the exception
    def perform(exception_class:, message:, backtrace:, context:)
      # Recreate the exception
      begin
        exception = exception_class.constantize.new(message)
      rescue NameError
        # If the exception class can't be found, use a generic exception
        exception = RuntimeError.new("#{exception_class}: #{message}")
      end

      # Set the backtrace if available
      exception.set_backtrace(backtrace) if backtrace.present?

      # Send to PostHog
      PosthogExceptions.notify(exception, context)
    rescue StandardError => e
      # Log any errors in the job itself
      if defined?(Rails) && Rails.logger
        Rails.logger.error("Error in PosthogExceptionsJob: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n")) if e.backtrace
      else
        warn("Error in PosthogExceptionsJob: #{e.message}")
        warn(e.backtrace.join("\n")) if e.backtrace
      end
    end
  end
end
