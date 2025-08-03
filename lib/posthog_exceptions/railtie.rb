module PosthogExceptions
  # Rails integration via Railtie
  class Railtie < Rails::Railtie
    initializer 'posthog_exceptions.middleware' do |app|
      # Insert our middleware after the debug exceptions middleware
      # so we can catch exceptions that are raised and shown in development
      app.config.middleware.insert_after ActionDispatch::DebugExceptions, PosthogExceptions::Middleware
    end

    config.after_initialize do
      # Set up error handling for ActionController
      ActiveSupport.on_load(:action_controller) do
        include PosthogExceptions::ControllerMethods
      end

      Rails.logger.info "PosthogExceptions initialized for #{PosthogExceptions.configuration.environment} environment"
    end

    rake_tasks do
      namespace :posthog_exceptions do
        desc 'Test PostHog exception tracking by sending a test exception'
        task test: :environment do
          # Raise a test exception
          raise 'This is a test exception from PosthogExceptions'
        rescue StandardError => e
          # Report it to PostHog
          success = PosthogExceptions.notify(e, {
                                               source: 'rake task',
                                               test: true
                                             })

          if success
            puts 'Successfully sent test exception to PostHog'
          else
            puts 'Failed to send test exception to PostHog'
          end
        end
      end
    end
  end
end
