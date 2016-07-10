module Api
  module V1
    class RepositoriesController < ActionController::Base
      before_filter :maybe_find_repo, only: [:update, :show, :destroy]
      
      def create
        args = repository_params
        @repo = Repository.create(args.merge(public_id: UUID.generate))
        render(json: { public_id: @repo.public_id })
      end

      def show
        if @repo
          render(json: { url: @repo.url, public_id: @repo.public_id })
        else
          render(nothing: true, status: :not_found)
        end
      end
      
      def update
        apply_to_repo do
          @repo.update_attributes(repository_params)
        end
      end

      def destroy
        apply_to_repo do
          @repo.destroy
        end
      end

      private

      def apply_to_repo
        status = :not_found
        if @repo
          yield
          status = :ok
        end
        render(nothing: true, status: status)
      end

      def maybe_find_repo
        id = params.fetch('id', nil)
        @repo = Repository.where(public_id: id).first
      end
      
      def repository_params
        params.require(:repository).permit(:url)
      end
    end
  end
end
