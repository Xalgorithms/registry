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
        rule_collection do
          Rule.all.to_a
        end
      end

      def since
        rule_collection do
          Rule.all.select do |rm|
            dt = rm.updated_at || Time.now
            dt.to_s(:number).to_i > params[:key].to_i
          end
        end
      end
      
      def create
        @rule = Rule.create(rule_params.merge(public_id: UUID.generate))
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

      def rule_collection
        rules = yield

        latest_update = rules.map(&:updated_at).compact.sort { |a, b| b - a }.first
        latest = (latest_update ? latest_update : Time.now).to_s(:number)
        render(json: {
                 rules: rules.map { |rm| "#{rm.ns}:#{rm.name}:#{rm.version}" },
                 since: latest
               })        
      end
      
      def rule_params
        params.require(:rule).permit(:ns, :name, :version)
      end
    end
  end
end
