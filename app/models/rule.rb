class Rule
  include Mongoid::Document

  field :name,      type: String
  field :public_id, type: String
  field :version,   type: String
  
  belongs_to :repository
end
