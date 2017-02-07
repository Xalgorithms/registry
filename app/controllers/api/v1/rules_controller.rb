require 'remotes/client'

module Api
  module V1
    class RulesController < ActionController::Base
      def by_ns_name_version
        @rule = Rule.where(ns: params[:ns], name: params[:name], version: params[:version]).first
        if @rule
          if !@rule.content
            Rails.logger.info('# getting content for the rule')
            cl = Remotes::Client.new(@rule.repository.url)
            res = cl.get(@rule.public_id, @rule.version) do |content|
              @rule.content = content
              @rule.save
            end
          end
        else
          Rails.logger.warn("? Failed locate rule (ns=#{params[:ns]}; name: #{params[:name]}; version=#{params[:version]})")
        end

        if @rule && @rule.content
          render(json: @rule.content)
        else
          render(nothing: true, status: :not_found)
        end
      end

      def index
        rule_collection
      end

      def since
        rv = rule_collection do |all_rules|
          # TODO: +1.second is a hack. let's do better
          all_rules.where(updated_at: { '$gt' => Time.parse(params['since']) + 1.second })
        end
      end
      
      def create
        @rule = Rule.create(rule_params.except(:id).merge(public_id: rule_params[:id]))
        @rule.repository = Repository.where(public_id: params[:repository_id]).first
        @rule.save
        render(json: { id: @rule.public_id})
      end

      def update
        orule = Rule.where(public_id: params['id']).first
        @rule = Rule.create(rule_params.merge(repository: orule.repository, name: orule.name, ns: orule.ns, public_id: UUID.generate))
        render(json: { id: @rule.public_id })
      end

      def destroy
        Rule.where(public_id: params['id']).first.destroy
        render(nothing: true)
      end

      private

      def rule_collection(&bl)
        all_rules = Rule.all.order_by(updated_at: 'asc')
        rules = bl ? bl.call(all_rules) : all_rules

        latest_update = rules.last ? rules.last : all_rules.last
        render(json: {
                 rules: rules.map { |rm| "#{rm.ns}:#{rm.name}:#{rm.version}" },
                 since: latest_update.updated_at.to_s(:number)
               })        
      end
      
      def rule_params
        params.require(:rule).permit(:ns, :name, :version, :id)
      end
    end
  end
end
