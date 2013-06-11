class ActionController::Parameters::Filter
  cattr_accessor :action_on_unpermitted_parameters,
                 :unpermitted_parameters_handler
  attr_reader :filters, :input, :output

  def self.configure(config)
    self.action_on_unpermitted_parameters = config.delete(:action_on_unpermitted_parameters) do
      (Rails.env.test? || Rails.env.development?) ? :log : false
    end

    self.unpermitted_parameters_handler = config.delete(:unpermitted_parameters_handler)
  end

  def initialize(input)
    @input = input
    @output = input.class.new
  end

  def permit(*filters)
    @filters = filters

    case unpermitted_parameters_handler
    when :passthrough
      output.update input
    else
      filter do |key, value, permitted|
        output[key] = value if permitted
      end
    end

    unpermitted_parameters!
    output.permit!
  end

  protected

    def filter(&block)
      skipped = Set.new input.keys
      filters.each do |filter|
        case filter
        when Symbol, String
          permitted_scalar_filter(filter) do |key, value, permitted|
            yield key, value, permitted
            skipped.delete(key.to_s)
          end
        when Hash then
          hash_filter(filter, &block)
          skipped.subtract(filter.keys.map(&:to_s))
        end
      end
      skipped.each do |key|
        yield key, input[key], false
      end
    end

  private

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

    def permitted_scalar?(value)
      PERMITTED_SCALAR_TYPES.any? {|type| value.is_a?(type)}
    end

    def array_of_permitted_scalars?(value)
      if value.is_a?(Array)
        value.all? {|element| permitted_scalar?(element)}
      end
    end

    def permitted_scalar_filter(key)
      if input.has_key?(key)
        yield key, input[key], permitted_scalar?(input[key])
      end

      input.keys.grep(/\A#{Regexp.escape(key.to_s)}\(\d+[if]?\)\z/).each do |key|
        yield key, input[key], permitted_scalar?(input[key])
      end
    end

    def array_of_permitted_scalars_filter(key, hash = input)
      if hash.has_key?(key)
        yield key, hash[key], array_of_permitted_scalars?(hash[key])
      end
    end

    def hash_filter(filter, &block)
      filter = filter.with_indifferent_access

      # Slicing filters out non-declared keys.
      input.slice(*filter.keys).each do |key, value|
        return unless value

        if filter[key] == []
          # Declaration {:comment_ids => []}.
          array_of_permitted_scalars_filter(key, &block)
        else
          # Declaration {:user => :name} or {:user => [:name, :age, {:adress => ...}]}.
          values = each_element(value) do |element, index|
            if element.is_a?(Hash)
              element = input.class.new(element) unless element.respond_to?(:permit)
              element.permit(*Array.wrap(filter[key]))
            elsif filter[key].is_a?(Hash) && filter[key][index] == []
              array_of_permitted_scalars_filter(index, value, &block)
            else
              yield key, element, false
              nil
            end
          end
          yield key, values, true
        end
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

    def unpermitted_parameters!
      return unless action_on_unpermitted_parameters

      keys = unpermitted_keys - NEVER_UNPERMITTED_PARAMS

      if keys.any?
        case action_on_unpermitted_parameters
        when :log
          name = "unpermitted_parameters.action_controller"
          ActiveSupport::Notifications.instrument(name, :keys => keys)
        when :raise
          raise ActionController::UnpermittedParameters.new(keys)
        end
      end
    end

    def unpermitted_keys
      [].tap do |result|
        filter do |key, value, permitted|
          result << key unless permitted
        end
      end
    end
end
