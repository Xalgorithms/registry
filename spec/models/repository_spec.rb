require 'rails_helper'

RSpec.describe Repository, type: :model do
  include Randomness

  before(:all) do
    Repository.destroy_all
    Rule.destroy_all
  end
  
  it 'should have many rules' do
    repositories = rand_times.map { create(:repository) }
    ids = rand_times.map do
      repo = rand_one(repositories)
      rule = create(:rule, repository: repo)

      { rule_id: rule.id.to_s, repo_id: repo.id.to_s }
    end

    ids.each do |o|
      expect(Repository.find(o[:repo_id]).rules).to include(Rule.find(o[:rule_id]))
    end
  end
end
