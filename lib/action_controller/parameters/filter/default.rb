class ActionController::Parameters
  class Filter::Default < Filter
    protected
      def apply_filters
        filter do |key, value, permitted|
          output[key] = value if permitted
        end
      end
  end
end
