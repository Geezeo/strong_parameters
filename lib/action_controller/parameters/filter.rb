class ActionController::Parameters::Filter
  # Never raise an UnpermittedParameters exception because of these params
  # are present. They are added by Rails and it's of no concern.
  NEVER_UNPERMITTED_PARAMS = %w( controller action )

  cattr_accessor :action_on_unpermitted_parameters, :instance_accessor => false
  attr_reader :input

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

    unpermitted_parameters!(params) if self.class.action_on_unpermitted_parameters

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

  private

    def array_of_permitted_scalars_filter(params, key, hash = input)
      if hash.has_key?(key) && array_of_permitted_scalars?(hash[key])
        params[key] = hash[key]
      end
    end

    def each_element(value)
      if value.is_a?(Array)
        value.map { |el| yield el }.compact
        # fields_for on an array of records uses numeric hash keys.
      elsif value.is_a?(Hash) && value.keys.all? { |k| k =~ /\A-?\d+\z/ }
        hash = value.class.new
        value.each { |k,v| hash[k] = yield(v, k) }
        hash
      else
        yield value
      end
    end

    def hash_filter(params, filter)
      filter = filter.with_indifferent_access

      # Slicing filters out non-declared keys.
      input.slice(*filter.keys).each do |key, value|
        return unless value

        if filter[key] == []
          # Declaration {:comment_ids => []}.
          array_of_permitted_scalars_filter(params, key)
        else
          # Declaration {:user => :name} or {:user => [:name, :age, {:adress => ...}]}.
          params[key] = each_element(value) do |element, index|
            if element.is_a?(Hash)
              element = input.class.new(element) unless element.respond_to?(:permit)
              element.permit(*Array.wrap(filter[key]))
            elsif filter[key].is_a?(Hash) && filter[key][index] == []
              array_of_permitted_scalars_filter(params, index, value)
            end
          end
        end
      end
    end

    def permitted_scalar_filter(params, key)
      if input.has_key?(key) && permitted_scalar?(input[key])
        params[key] = input[key]
      end

      input.keys.grep(/\A#{Regexp.escape(key.to_s)}\(\d+[if]?\)\z/).each do |key|
        if permitted_scalar?(input[key])
          params[key] = input[key]
        end
      end
    end

    def unpermitted_keys(params)
      input.keys - params.keys - NEVER_UNPERMITTED_PARAMS
    end

    def unpermitted_parameters!(params)
      return unless self.class.action_on_unpermitted_parameters

      unpermitted_keys = unpermitted_keys(params)

      if unpermitted_keys.any?
        case self.class.action_on_unpermitted_parameters
        when :log
          name = "unpermitted_parameters.action_controller"
          ActiveSupport::Notifications.instrument(name, :keys => unpermitted_keys)
        when :raise
          raise ActionController::UnpermittedParameters.new(unpermitted_keys)
        end
      end
    end
end
