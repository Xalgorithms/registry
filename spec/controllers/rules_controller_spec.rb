require 'rails_helper'

require 'remotes/client'

describe Api::V1::RulesController, type: :controller do
  include Randomness
  
  def response_json
    MultiJson.decode(response.body)
  end
  
  describe 'GET :name/:version' do
    def make_content
      filters = rand_array_of_words(5).inject({}) do |o, w|
        o.merge(w => 'unknown')
      end
      actions = rand_array_of_words(5).inject({}) do |o, w|
        o.merge(w => 'unknown')
      end
      
      { 'filters' => filters, 'actions' => actions }
    end

    def verify_loaded_rules(rules)
      rules.each do |vals|
        rule = vals[:rule]
        doc = RuleDocument.find(vals[:doc_id])
        expect(doc).to_not be_nil

        get(:by_version_content, yield(rule))

        expect(response).to be_success
        expect(response).to have_http_status(200)
        expect(response_json).to eql(doc.content)
      end
    end

    def make_repositories
      rand_times.map { create(:repository) }
    end
    
    def make_rules()
      repos = make_repositories
      names = rand_array_of_words(5)
      rand_times.map do
        create(:rule, name: rand_one(names), version: Faker::Number.hexadecimal(6), repository: rand_one(repos))
      end
    end
    
    def make_rules_with_docs
      names = rand_array_of_words(5)
      rand_times.map do
        doc_id = RuleDocument.create(content: make_content)._id.to_s
        rule = create(:rule, name: rand_one(names), version: Faker::Number.hexadecimal(6), doc_id: doc_id)
        
        { rule: rule, doc_id: doc_id }
      end
    end
    
    it 'loads rule content by name and version' do
      verify_loaded_rules(make_rules_with_docs) do |rule|
        { id: rule.name, version: rule.version }
      end
    end

    it 'loads rule content by public_id and version' do
      verify_loaded_rules(make_rules_with_docs) do |rule|
        { id: rule.public_id, version: rule.version }
      end
    end

    let(:client) { instance_double(Remotes::Client) }
      
    it 'loads rule content from a remote if content is not cached' do
      make_rules.each do |rule|
        content = make_content

        expect(Remotes::Client).to receive(:new).with(rule.repository.url).and_return(client)
        expect(client).to receive(:get).with(rule.name, rule.version).and_return(content)

        get(:by_version_content, id: rule.name, version: rule.version)

        rule = Rule.find(rule.id)
        expect(rule.document).to_not be_nil
        expect(rule.document.content).to eql(content)
        
        expect(response).to be_success
        expect(response).to have_http_status(200)
        expect(response_json).to eql(content)
      end
    end

    it 'should fail gracefully if the remote client does not yield a result' do
      make_rules.each do |rule|
        expect(Remotes::Client).to receive(:new).with(rule.repository.url).and_return(client)
        expect(client).to receive(:get).with(rule.name, rule.version).and_return(nil)

        get(:by_version_content, id: rule.name, version: rule.version)

        rule = Rule.find(rule.id)
        expect(rule.document).to be_nil
        
        expect(response).to_not be_success
        expect(response).to have_http_status(404)
      end
    end
    
    it 'lists all rules with versions' do
      vals = rand_array_of_words(5).map do |name|
        { name: name, public_id: UUID.generate }
      end

      versions = rand_times(10).map do
        create(:rule, rand_one(vals).merge(version: Faker::Number.hexadecimal(6)))
      end.inject({}) do |o, rule|
        o.merge(rule.name => o.fetch(rule.name, []) << rule.version)
      end

      expected = Rule.all.inject({}) do |o, rule|
        o.merge(rule.name => { 'id' => rule.public_id, 'versions' => versions.fetch(rule.name) })
      end

      get(:index)

      expect(response).to be_success
      expect(response).to have_http_status(200)

      expect(response_json).to eql(expected)
    end
    
    it 'delivers versions when all rules of a name are requested' do
      vals = rand_array_of_words(5).map do |name|
        { name: name, public_id: UUID.generate }
      end

      counts = vals.inject({}) do |o, v|
        count = rand_times(10).map do |i|
          create(:rule, v.merge(version: i.to_s))
        end.length
        
        o.merge(v[:name] => count)
      end

      vals.each do |v|
        name = v[:name]
        rules = Rule.where(name: name)
        expect(rules.length).to eql(counts[name])

        get(:show, id: name)

        expect(response).to be_success
        expect(response).to have_http_status(200)

        versions = rules.map { |rule| rule.version }
        expect(response_json.fetch('versions', [])).to eql(versions)
      end
    end

    it 'delivers versions when all rules of a public_id are requested' do
      public_ids = rand_times(5).map do
        UUID.generate
      end

      counts = public_ids.inject({}) do |o, public_id|
        count = rand_times(10).map do |i|
          create(:rule, public_id: public_id, version: i.to_s)
        end.length
        
        o.merge(public_id => count)
      end

      public_ids.each do |public_id|
        rules = Rule.where(public_id: public_id)
        expect(rules.length).to eql(counts[public_id])

        get(:show, id: public_id)

        expect(response).to be_success
        expect(response).to have_http_status(200)

        versions = rules.map { |rule| rule.version }
        expect(response_json.fetch('versions', [])).to eql(versions)
      end
    end

    it 'responds with a failure when versions are requested for an unknown rule' do
      rand_times(5).each do |name|
        get(:show, id: name)

        expect(response).to_not be_success
        expect(response).to have_http_status(404)
      end
    end
    
    it 'generates a failure when unknown rules or versions are requested' do
      rule0 = create(:rule)

      rand_times.map do |i|
        { id: rule0.name, version: i.to_s }
      end.each do |vals|
        get(:by_version_content, vals)

        expect(response).to_not be_success
        expect(response).to have_http_status(404)

        expect(response.body).to be_empty
      end
    end

    it 'should generate a new rule when updating with a new version' do
      rand_times.map do
        create(:rule)
      end.each do |rule|
        @request.headers['Content-Type'] = 'application/json'
        rand_array_of_hexes(5).each do |ver|
          put(:update, id: rule.name, rule: { version: ver })

          expect(response).to be_success
          expect(response).to have_http_status(200)

          prev_rule = Rule.find_by(name: rule.name, version: rule.version)
          expect(prev_rule).to_not be_nil
          expect(prev_rule.public_id).to eql(rule.public_id)
          
          new_rule = Rule.find_by(name: rule.name, version: ver)
          expect(new_rule).to_not be_nil
          # FIX ME: this fails sometimes when there is no network
          expect(new_rule.public_id).to eql(prev_rule.public_id)

          expect(response_json.fetch('public_id', nil)).to eql(new_rule.public_id)
        end
      end
    end

    it 'should create rules when PUTting a non-existing rule' do
      rand_array_of_words.each do |name|
        @request.headers['Content-Type'] = 'application/json'
        rand_array_of_hexes(5).each do |ver|
          put(:update, id: name, rule: { version: ver })

          expect(response).to be_success
          expect(response).to have_http_status(200)

          rule = Rule.find_by(name: name, version: ver)
          expect(rule).to_not be_nil
          expect(rule.public_id).to_not be_nil

          expect(response_json.fetch('public_id', nil)).to eql(rule.public_id)
        end
      end      
    end

    it 'allows setting a rule repository' do
      make_repositories.each do |repo|
        name = Faker::Hipster.word
        opts = { version: Faker::Number.hexadecimal(6), repository: { id: repo.public_id } }

        put(:update, id: name, rule: opts)

        rule = Rule.find_by(name: name)
        expect(rule).to_not be_nil
        # FIXME: this fails sometimes when there is no network (uuid)
        expect(rule.repository).to eql(repo)
      end
    end
  end
end
