require 'faraday'
require 'faraday_middleware'

module Remotes
  class Client
    def initialize(url)
      @conn = Faraday.new(url) do |f|
        f.request(:url_encoded)
        f.request(:json)
        f.response(:json, :content_type => /\bjson$/)
        f.adapter(Faraday.default_adapter)        
      end
    end

    def get(public_id, version)
      # TODO: the API prefix should probably be in the registration??
      resp = @conn.get("/api/v1/rules/#{public_id}/versions/#{version}")
      if resp.success?
        Rails.logger.info("< #{resp.status}: #{resp.body}")
        yield(resp.body)
      else
        Rails.logger.error("! Failed to get content")
      end
    end
  end
end
