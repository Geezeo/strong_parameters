require 'date'
require 'bigdecimal'
require 'stringio'

require 'active_support/concern'
require 'active_support/core_ext/hash/indifferent_access'
require 'action_controller'
require 'action_dispatch/http/upload'

module ActionController
  class ParameterMissing < IndexError
    attr_reader :param

    def initialize(param)
      @param = param
      super("key not found: #{param}")
    end
  end

  class UnpermittedParameters < IndexError
    attr_reader :params

    def initialize(params)
      @params = params
      super("found unpermitted parameters: #{params.join(", ")}")
    end
  end

  class Parameters < ActiveSupport::HashWithIndifferentAccess
    cattr_accessor :action_on_missing_parameter
    attr_accessor :permitted
    alias :permitted? :permitted

    delegate :permit, to: :filter

    def self.configure(config)
      self.action_on_missing_parameter =
          config.delete(:action_on_missing_parameter)
    end

    def initialize(attributes = nil)
      super(attributes)
      @permitted = false
    end

    def permit!
      each_pair do |key, value|
        convert_hashes_to_parameters(key, value)
        self[key].permit! if self[key].respond_to? :permit!
      end

      @permitted = true
      self
    end

    def require(key)
      self[key].tap do |value|
        if value.blank?
          case action_on_missing_parameter
          when :log
            name = "missing_parameter.action_controller"
            ActiveSupport::Notifications.instrument name, key: key
          else
            raise ActionController::ParameterMissing.new(key)
          end
        end
      end
    end

    alias :required :require

    def [](key)
      convert_hashes_to_parameters(key, super)
    end

    def fetch(key, *args)
      convert_hashes_to_parameters(key, super)
    rescue KeyError, IndexError
      raise ActionController::ParameterMissing.new(key)
    end

    def slice(*keys)
      self.class.new(super).tap do |new_instance|
        new_instance.instance_variable_set :@permitted, @permitted
      end
    end

    def dup
      self.class.new(self).tap do |duplicate|
        duplicate.default = default
        duplicate.instance_variable_set :@permitted, @permitted
      end
    end

    protected
      def convert_value(value)
        if value.class == Hash
          self.class.new_from_hash_copying_default(value)
        elsif value.is_a?(Array)
          value.dup.replace(value.map { |e| convert_value(e) })
        else
          value
        end
      end

    private

      def convert_hashes_to_parameters(key, value)
        if value.is_a?(Parameters) || !value.is_a?(Hash)
          value
        else
          # Convert to Parameters on first access
          self[key] = self.class.new(value)
        end
      end

      def filter
        Filter.new self
      end
  end

  module StrongParameters
    extend ActiveSupport::Concern

    included do
      rescue_from(ActionController::ParameterMissing) do |parameter_missing_exception|
        render :text => "Required parameter missing: #{parameter_missing_exception.param}", :status => :bad_request
      end
    end

    def params
      @_params ||= Parameters.new(request.parameters)
    end

    def params=(val)
      @_params = val.is_a?(Hash) ? Parameters.new(val) : val
    end
  end
end

ActionController::Base.send :include, ActionController::StrongParameters
