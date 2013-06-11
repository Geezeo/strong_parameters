module ActiveModel
  class ForbiddenAttributes < StandardError
  end

  module ForbiddenAttributesProtection
    mattr_accessor :action_on_forbidden_attributes

    def self.configure(config)
      self.action_on_forbidden_attributes = config.action_on_forbidden_attributes
    end

    def sanitize_for_mass_assignment(*options)
      new_attributes = options.first
      if new_attributes.respond_to?(:permitted) && !new_attributes.permitted?
        case action_on_forbidden_attributes
        when :log
          name = "forbidden_attributes.active_model"
          ActiveSupport::Notifications.instrument name
        else
          raise ActiveModel::ForbiddenAttributes
        end
      end
      super
    end
  end
end
