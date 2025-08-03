# PostHog Exception

A Ruby gem that serves as a wrapper around the PostHog error tracking API.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'posthog_exceptions'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install posthog_exceptions
```

## Configuration

### Rails

For Rails applications, create an initializer at `config/initializers/posthog_exceptions.rb`:

```ruby
PosthogExceptions.configure do |config|
  config.api_key = 'your_posthog_api_key'
  config.api_url = 'https://us.i.posthog.com/i/v0/e/' # Default PostHog API URL
  config.environment = Rails.env
  config.enabled = !Rails.env.test? # Disable in test environment
  config.ignored_exceptions = ['ActiveRecord::RecordNotFound', 'ActionController::RoutingError']
end
```

### Non-Rails Applications

For non-Rails applications, configure the gem before using it:

```ruby
require 'posthog_exceptions'

PosthogExceptions.configure do |config|
  config.api_key = 'your_posthog_api_key'
  config.api_url = 'https://us.i.posthog.com/i/v0/e/'
  config.environment = ENV['RACK_ENV'] || 'development'
  config.enabled = true
  config.ignored_exceptions = ['StandardError::NotFound']
end
```

## Usage

### Manual Exception Tracking

You can manually track exceptions with context data:

```ruby
begin
  # Some code that might raise an exception
  result = some_dangerous_operation
rescue => e
  # Track the exception with context
  PosthogExceptions.notify(e, {
    user_id: current_user.analytics_uuid,
    custom_data: {
      operation: 'some_dangerous_operation',
      input_params: params[:input]
    }
  })

  # Re-raise or handle as needed
  raise
end
```

### Custom Error Tracking with Additional Context

```ruby
def process_payment
  begin
    # Payment processing code
    payment_processor.charge(amount)
  rescue PaymentError => e
    PosthogExceptions.notify(e, {
      payment_amount: amount,
      payment_method: payment_method,
      customer_id: customer.id
    })

    # Handle the error appropriately
    false
  end
end
```

### Rails Controller Helper

In Rails applications, a helper method is automatically added to all controllers:

```ruby
class ApplicationController < ActionController::Base
  def some_action
    begin
      # Some code that might raise an exception
      result = some_dangerous_operation
    rescue => e
      # Use the helper method to report the exception
      posthog_report_exception(e, {
        custom_context: 'Additional information'
      })
      
      # Handle the error appropriately
      render_error_page
    end
  end
end
```

### Asynchronous Exception Tracking

For better performance, you can track exceptions asynchronously (requires ActiveJob):

```ruby
PosthogExceptions.notify_async(exception, context)
```

### Testing the Integration

For Rails applications, a rake task is provided to test the integration:

```bash
$ rake posthog_exceptions:test
```

## Features

- Automatic exception capturing in Rails applications
- Manual exception tracking with custom context
- Asynchronous exception tracking using ActiveJob
- Configurable ignored exceptions
- Detailed exception information including stack traces
- User identification and context
- Rails controller integration

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/jhliberty/posthog_exceptions.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).