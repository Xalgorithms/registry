class RulesController < ApplicationController
  def index
    @rules = Rule.all.inject({}) do |o, rm|
      k = "#{rm.ns}:#{rm.name}"
      o.merge(k => o.fetch(k, []) << rm)
    end
  end
end
