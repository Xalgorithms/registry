module Api
  module V1
    class NamespacesController < ActionController::Base
      def index
        render(json: Rule.distinct(:ns))
      end
    end
  end
end
