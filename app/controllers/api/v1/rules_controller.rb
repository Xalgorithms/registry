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
        repo = Repository.find_by(public_id: repo_public_id)
        args = args.except('repository').merge(repository: repo)
        if @rule
          @rule.update_attributes(args)
          render(json: { public_id: @rule.public_id })
        elsif params.key?('id')
          @rule = Rule.create(args.merge(name: params['id'], public_id: UUID.generate))
          render(json: { public_id: @rule.public_id })
        end
      end
      
      def by_version_content
        if @doc
          render(json: @doc.content)
        else
          render(nothing: true, status: :not_found)
        end
      end

      def index
        versions = @rules.inject({}) do |o, rule|
          o.merge(rule.name => o.fetch(rule.name, []) << rule.version)
        end

        results = @rules.map do |rule|
          { name: rule.name, id: rule.public_id, versions: versions.fetch(rule.name, nil) }
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
          @rule = Rule.find_by(name: id, version: version)
          @rule = Rule.find_by(public_id: id, version: version) unless @rule
        end
      end

      def maybe_find_rule
        id = params.fetch('id', nil)
        if id
          @rule = Rule.find_by(name: id)
          @rule = Rule.find_by(public_id: id) if !@rule
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
