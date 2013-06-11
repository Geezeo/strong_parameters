# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require 'test/unit'
require 'rails'

class FakeApplication < Rails::Application; end

Rails.application = FakeApplication
Rails.configuration.action_controller = ActiveSupport::OrderedOptions.new

require 'strong_parameters'

module ActionController
  SharedTestRoutes = ActionDispatch::Routing::RouteSet.new
  SharedTestRoutes.draw do
    match ':controller(/:action)'
  end

  class Base
    include ActionController::Testing
    include SharedTestRoutes.url_helpers
  end

  class ActionController::TestCase
    setup do
      @routes = SharedTestRoutes
    end
  end
end

class ActiveSupport::TestCase
  def assert_logged(message)
    old_logger = ActionController::Base.logger
    log = StringIO.new
    ActionController::Base.logger = Logger.new(log)

    begin
      yield

      log.rewind
      assert_match message, log.read
    ensure
      ActionController::Base.logger = old_logger
    end
  end
end

# ActionController::Parameters.configure(
#     action_on_missing_parameter: :log)
ActionController::Parameters::Filter.configure(
    action_on_unpermitted_parameters: false)

# Load support files
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }
