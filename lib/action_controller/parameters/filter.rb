class ActionController::Parameters::Filter
  # Never raise an UnpermittedParameters exception because of these params
  # are present. They are added by Rails and it's of no concern.
  NEVER_UNPERMITTED_PARAMS = %w( controller action )

  cattr_accessor :action_on_unpermitted_parameters, :parameter_filter
  attr_reader :input

  def self.configure(config)
    self.action_on_unpermitted_parameters = config.fetch(:action_on_unpermitted_parameters) do
      (Rails.env.test? || Rails.env.development?) ? :log : false
    end

    parameter_filter_config = config.fetch :parameter_filter, :default
    self.parameter_filter = if parameter_filter_config.is_a? Class
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

    filters.each do |filter|
      case filter
      when Symbol, String
        permitted_scalar_filter(params, filter)
      when Hash then
        hash_filter(params, filter)
      end
    end

    unpermitted_parameters!(params) if action_on_unpermitted_parameters

    params.permit!
  end

  protected

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
end
