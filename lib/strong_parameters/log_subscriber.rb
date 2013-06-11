module StrongParameters
  class LogSubscriber < ActiveSupport::LogSubscriber
    def forbidden_attributes(event)
      debug("Forbidden attributes")
    end

    def missing_parameter(event)
      debug("Missing parameter: #{event.payload[:key]}")
    end

    def unpermitted_parameters(event)
      unpermitted_keys = event.payload[:keys]
      debug("Unpermitted parameters: #{unpermitted_keys.join(", ")}")
    end

    def logger
      ActionController::Base.logger
    end
  end
end

StrongParameters::LogSubscriber.attach_to :action_controller
StrongParameters::LogSubscriber.attach_to :active_model
