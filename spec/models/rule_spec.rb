require 'rails_helper'

RSpec.describe Rule, type: :model do
  include Randomness
  
  before(:all) do
    Repository.destroy_all
    Rule.destroy_all
  end
  
  it 'should belong to a repository' do
    repositories = rand_times.map { create(:repository) }
    ids = rand_times.map do
      repo = rand_one(repositories)
      rule = create(:rule, repository: repo)

      { rule_id: rule.id, repo_id: repo.id }
    end

    ids.each do |o|
      expect(Rule.find(o[:rule_id]).repository).to eql(Repository.find(o[:repo_id]))
    end
  end
end
