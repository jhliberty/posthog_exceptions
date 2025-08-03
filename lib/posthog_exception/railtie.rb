module PosthogException
  # Rails integration via Railtie
  class Railtie < Rails::Railtie
    initializer 'posthog_exception.middleware' do |app|
      # Insert our middleware after the debug exceptions middleware
      # so we can catch exceptions that are raised and shown in development
      app.config.middleware.insert_after ActionDispatch::DebugExceptions, PosthogException::Middleware
    end

    config.after_initialize do
      # Set up error handling for ActionController
      ActiveSupport.on_load(:action_controller) do
        include PosthogException::ControllerMethods
      end

      Rails.logger.info "PosthogException initialized for #{PosthogException.configuration.environment} environment"
    end

    rake_tasks do
      namespace :posthog_exception do
        desc 'Test PostHog exception tracking by sending a test exception'
        task test: :environment do
          # Raise a test exception
          raise 'This is a test exception from PosthogException'
        rescue StandardError => e
          # Report it to PostHog
          success = PosthogException.notify(e, {
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
