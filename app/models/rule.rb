class Rule
  include Mongoid::Document

  field :ns,        type: String
  field :name,      type: String
  field :public_id, type: String
  field :version,   type: String
  field :content,   type: Hash
  
  belongs_to :repository
end
