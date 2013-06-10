class ActionController::Parameters
  class Filter::Default < Filter
    protected
      def apply_filters
        filters.each do |filter|
          case filter
          when Symbol, String
            permitted_scalar_filter(filter)
          when Hash then
            hash_filter(filter)
          end
        end
      end

      def unpermitted_keys
        input.keys - output.keys
      end

    private

      def array_of_permitted_scalars_filter(key, hash = input)
        if hash.has_key?(key) && array_of_permitted_scalars?(hash[key])
          output[key] = hash[key]
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

      def hash_filter(filter)
        filter = filter.with_indifferent_access

        # Slicing filters out non-declared keys.
        input.slice(*filter.keys).each do |key, value|
          return unless value

          if filter[key] == []
            # Declaration {:comment_ids => []}.
            array_of_permitted_scalars_filter(key)
          else
            # Declaration {:user => :name} or {:user => [:name, :age, {:adress => ...}]}.
            output[key] = each_element(value) do |element, index|
              if element.is_a?(Hash)
                element = input.class.new(element) unless element.respond_to?(:permit)
                element.permit(*Array.wrap(filter[key]))
              elsif filter[key].is_a?(Hash) && filter[key][index] == []
                array_of_permitted_scalars_filter(index, value)
              end
            end
          end
        end
      end

      def permitted_scalar_filter(key)
        if input.has_key?(key) && permitted_scalar?(input[key])
          output[key] = input[key]
        end

        input.keys.grep(/\A#{Regexp.escape(key.to_s)}\(\d+[if]?\)\z/).each do |key|
          if permitted_scalar?(input[key])
            output[key] = input[key]
          end
        end
      end
  end
end
