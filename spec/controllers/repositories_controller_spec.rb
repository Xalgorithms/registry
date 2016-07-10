require 'rails_helper'

describe Api::V1::RepositoriesController, type: :controller do
  include Randomness
  
  def response_json
    MultiJson.decode(response.body)
  end

  def make_repositories
    rand_times.map do
      create(:repository)
    end
  end
  
  it 'will create a new repository' do
    rand_array_of_urls.map do |url|
      post(:create, repository: { url: url })
      
      expect(response).to be_success
      expect(response).to have_http_status(200)

      repo = Repository.find_by(url: url)
      expect(response_json.fetch('public_id')).to eql(repo.public_id)
    end
  end

  it 'will update an existing repository' do
    make_repositories.each do |repo|
      url = Faker::Internet.url

      @request.headers['Content-Type'] = 'application/json'
      put(:update, id: repo.public_id, repository: { url: url})      

      expect(response).to be_success
      expect(response).to have_http_status(200)

      repo = Repository.find(repo.id)
      expect(repo.url).to eql(url)
    end
  end

  it 'should not update a non-existant repo' do
    rand_times.map do
      { id: UUID.generate, url: Faker::Internet.url }
    end.each do |vals|
      put(:update, id: vals[:id], repository: vals.except(:id))

      expect(response).to_not be_success
      expect(response).to have_http_status(404)
    end
  end

  it 'should delete existing repos' do
    make_repositories.each do |repo|
      delete(:destroy, id: repo.public_id)

      expect(response).to be_success
      expect(response).to have_http_status(200)

      expect {
        Repository.find(repo.id)
      }.to raise_error(Mongoid::Errors::DocumentNotFound)
    end
  end

  it 'should not delete existing repos' do
    rand_array_of_uuids.map do |id|
      delete(:destroy, id: id)

      expect(response).to_not be_success
      expect(response).to have_http_status(404)
    end
  end

  it 'should allow fetching a repository by public id' do
    make_repositories.each do |repo|
      get(:show, id: repo.public_id)

      expect(response).to be_success
      expect(response).to have_http_status(200)

      expect(response_json).to eql('url' => repo.url, 'public_id' => repo.public_id)
    end
  end

  it 'should get an error fetching unknown repos' do
    rand_array_of_uuids.each do |id|
      get(:show, id: id)

      expect(response).to_not be_success
      expect(response).to have_http_status(404)
    end
  end
end
  
