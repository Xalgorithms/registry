FactoryGirl.define do
  factory :rule do
    ns        { Faker::Hacker.noun }
    name      { Faker::Hacker.noun }
    version   { Faker::Number.number(6) }
    public_id { UUID.generate }
  end
end
