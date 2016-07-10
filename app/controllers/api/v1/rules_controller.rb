require 'remotes/client'

module Api
  module V1
    class RulesController < ActionController::Base
      before_filter :maybe_find_rule_by_version, only: [:by_version_content]
      before_filter :maybe_find_document, only: [:by_version_content]
      before_filter :maybe_get_document, only: [:by_version_content]
      before_filter :maybe_find_rule, only: [:update]
      before_filter :maybe_find_rules, only: [:show]
      before_filter :find_all_rules, only: [:index]

      def update
        args = rule_params
        repo_public_id = args.fetch('repository', {}).fetch('id', nil)
        repo = Repository.where(public_id: repo_public_id).first
        args = args.except('repository').merge(repository: repo)

        public_id = @rule ? @rule.public_id : UUID.generate
        @rule = Rule.create(args.merge(name: params['id'], public_id: public_id))
        render(json: { public_id: @rule.public_id })
      end
      
      def by_version_content
        if @doc
          render(json: @doc.content)
        else
          render(nothing: true, status: :not_found)
        end
      end

      def index
        results = @rules.inject({}) do |o, rule|
          ro = o.fetch(rule.name, { id: rule.public_id, versions: [] })
          ro[:versions] << rule.version
          o.merge(rule.name => ro)
        end

        render(json: results)
      end
      
      def show
        if @rules && @rules.any?
          render(json: { versions: @rules.map(&:version) })
        else
          render(nothing: true, status: :not_found)
        end
      end

      private

      def rule_params
        params.require(:rule).permit(:version, repository: [:id])
      end
      
      def find_all_rules
        @rules = Rule.all
      end

      # TODO: id can be public_id or name, fix
      def maybe_find_rules
        id = params.fetch('id', nil)
        if id
          @rules = Rule.where(name: id)
          @rules = Rule.where(public_id: id) if @rules.empty?
        end
      end
      
      def maybe_find_rule_by_version
        id = params.fetch('id', nil)
        version = params.fetch('version', nil)
        if id && version
          @rule = Rule.where(name: id, version: version).first
          @rule = Rule.where(public_id: id, version: version).first unless @rule
        end
      end

      def maybe_find_rule
        id = params.fetch('id', nil)
        if id
          @rule = Rule.where(name: id).first
          @rule = Rule.where(public_id: id).first if !@rule
        end
      end

      def maybe_find_document
        @doc = @rule.document if @rule
      end

      def maybe_get_document
        if !@doc && @rule && @rule.repository
          content = get_rule_content(@rule.repository.url, @rule.name, @rule.version)
          if content
            @doc = RuleDocument.create(content: content)
            @rule.update_attributes(doc_id: @doc._id)
          end
        end
      end

      def get_rule_content(url, name, version)
        cl = Remotes::Client.new(url)
        cl.get(name, version)
      end
    end
  end
end
