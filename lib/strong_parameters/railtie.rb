require 'rails/railtie'

module StrongParameters
  class Railtie < ::Rails::Railtie
    if config.respond_to?(:app_generators)
      config.app_generators.scaffold_controller = :strong_parameters_controller
    else
      config.generators.scaffold_controller = :strong_parameters_controller
    end

    initializer "strong_parameters.config", :before => "action_controller.set_configs" do |app|
      ActionController::Parameters::Filter.configure app.config.action_controller
    end
  end
end
