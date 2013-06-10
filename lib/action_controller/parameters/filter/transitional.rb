class ActionController::Parameters
  class Filter::Transitional < Filter
    protected
      def apply_filters
        output.update input
      end
  end
end
