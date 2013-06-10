class ActionController::Parameters::Filter
  cattr_accessor :action_on_unpermitted_parameters, :parameter_filter
  attr_reader :input

  def self.configure(config)
    self.action_on_unpermitted_parameters = config.fetch(:action_on_unpermitted_parameters) do
      (Rails.env.test? || Rails.env.development?) ? :log : false
    end

    parameter_filter_config = config.fetch :parameter_filter, :default
    self.parameter_filter = if parameter_filter_config.respond_to? :new
      parameter_filter_config
    else
      const_get parameter_filter_config.to_s.camelize
    end
  end

  def self.for_parameters(input)
    parameter_filter.new input
  end

  def initialize(input)
    @input = input
  end

  def permit(*filters)
    params = input.class.new
    apply_filters(params, filters)
    unpermitted_parameters!(params)
    params.permit!
  end

  protected

    # Never raise an UnpermittedParameters exception because of these params
    # are present. They are added by Rails and it's of no concern.
    NEVER_UNPERMITTED_PARAMS = %w( controller action )

    # This is a white list of permitted scalar types that includes the ones
    # supported in XML and JSON requests.
    #
    # This list is in particular used to filter ordinary requests, String goes
    # as first element to quickly short-circuit the common case.
    #
    # If you modify this collection please update the README.
    PERMITTED_SCALAR_TYPES = [
      String,
      Symbol,
      NilClass,
      Numeric,
      TrueClass,
      FalseClass,
      Date,
      Time,
      # DateTimes are Dates, we document the type but avoid the redundant check.
      StringIO,
      IO,
      ActionDispatch::Http::UploadedFile,
      Rack::Test::UploadedFile,
    ]

    def array_of_permitted_scalars?(value)
      if value.is_a?(Array)
        value.all? {|element| permitted_scalar?(element)}
      end
    end

    def permitted_scalar?(value)
      PERMITTED_SCALAR_TYPES.any? {|type| value.is_a?(type)}
    end

  private

    def unpermitted_parameters!(params)
      return unless action_on_unpermitted_parameters

      unpermitted_keys = unpermitted_keys(params) - NEVER_UNPERMITTED_PARAMS

      if unpermitted_keys.any?
        case action_on_unpermitted_parameters
        when :log
          name = "unpermitted_parameters.action_controller"
          ActiveSupport::Notifications.instrument(name, :keys => unpermitted_keys)
        when :raise
          raise ActionController::UnpermittedParameters.new(unpermitted_keys)
        end
      end
    end
end
