require 'rails_helper'

require 'remotes/client'

describe Api::V1::RulesController, type: :controller do
  include Randomness
  
  before(:all) do
    Repository.destroy_all
    Rule.destroy_all
  end
  
  def response_json
    MultiJson.decode(response.body)
  end
  
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
    rules.each do |rule|
      get(:by_ns_name_version, yield(rule))

      expect(response).to be_success
      expect(response).to have_http_status(200)
      expect(response_json).to eql(rule.content)
    end
  end

  def make_repositories
    rand_times.map { create(:repository) }
  end
  
  def make_rules(add_content=true)
    repos = make_repositories
    names = rand_array_of_words(5)
    nss = rand_array_of_words(5)
    rand_times.map do
      content = add_content ? make_content : nil
      create(:rule, ns: rand_one(nss), name: rand_one(names), version: Faker::Number.hexadecimal(6), repository: rand_one(repos), content: content)
    end
  end
  
  it 'loads rule content' do
    verify_loaded_rules(make_rules) do |rule|
      { ns: rule.ns, name: rule.name, version: rule.version }
    end
  end

  let(:client) { instance_double(Remotes::Client) }
  
  it 'loads rule content from a remote if content is not cached' do
    make_rules(false).each do |rule|
      content = make_content
      
      expect(Remotes::Client).to receive(:new).with(rule.repository.url).and_return(client)
      expect(client).to receive(:get).with(rule.public_id, rule.version).and_yield(content)

      get(:by_ns_name_version, ns: rule.ns, name: rule.name, version: rule.version)

      rule = Rule.find(rule.id)
      expect(rule.content).to_not be_nil
      expect(rule.content).to eql(content)
      
      expect(response).to be_success
      expect(response).to have_http_status(200)
      expect(response_json).to eql(rule.content)
    end
  end

  it 'should fail gracefully if the remote client does not yield a result' do
    make_rules(false).each do |rule|
      expect(Remotes::Client).to receive(:new).with(rule.repository.url).and_return(client)
      expect(client).to receive(:get).with(rule.public_id, rule.version)

      get(:by_ns_name_version, ns: rule.ns, name: rule.name, version: rule.version)

      rule = Rule.find(rule.id)
      expect(rule.content).to be_nil
      
      expect(response).to_not be_success
      expect(response).to have_http_status(404)
    end
  end
  
  it 'generates a failure when unknown rules or versions are requested' do
    rule0 = create(:rule)

    rand_times.map do |i|
      { ns: 'ns', name: rule0.name, version: i.to_s }
    end.each do |vals|
      get(:by_ns_name_version, vals)

      expect(response).to_not be_success
      expect(response).to have_http_status(404)

      expect(response.body).to be_empty
    end
  end

  it 'should accept new rules for a repository' do
    repos = make_repositories
    names = rand_array_of_words(5)
    nss = rand_array_of_words(5)

    rand_times.map do
      { repository_id: rand_one(repos).public_id, rule: { ns: rand_one(nss), name: rand_one(names), version: Faker::Number.hexadecimal(6) } }
    end.each do |vals|
      @request.headers['Content-Type'] = 'application/json'

      post(:create, vals)

      expect(response).to be_success
      expect(response).to have_http_status(200)
      expect(response_json).to_not be_nil

      expect(response_json).to have_key('id')
      public_id = response_json['id']
      rule = Rule.where(public_id: public_id).first
      expect(rule).to_not be_nil
      expect(rule.repository).to eql(Repository.where(public_id: vals[:repository_id]).first)
      expect(rule.ns).to eql(vals[:rule][:ns])
      expect(rule.name).to eql(vals[:rule][:name])
      expect(rule.version).to eql(vals[:rule][:version])
    end
  end

  it 'should create a new rule when a new version is added' do
    rules = make_rules(false)
    rules.each do |rule|
      rand_times.each do
        ver = Faker::Number.hexadecimal(6)

        put(:update, { repository_id: rule.repository.public_id, id: rule.public_id, rule: { version: ver } })
        
        expect(response).to be_success
        expect(response).to have_http_status(200)
        expect(response_json).to_not be_nil

        expect(response_json).to have_key('id')
        public_id = response_json['id']
        expect(public_id).to_not eql(rule.public_id)

        nrule = Rule.where(public_id: public_id).first
        expect(nrule).to_not be_nil
        expect(nrule).to_not eql(rule)
        expect(nrule.repository).to eql(rule.repository)
        expect(nrule.ns).to eql(rule.ns)
        expect(nrule.name).to eql(rule.name)
        expect(nrule.version).to eql(ver)
      end
    end
  end
end
