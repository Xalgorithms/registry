class Rule
  include Mongoid::Document
  include Mongoid::Timestamps

  field :ns,        type: String
  field :name,      type: String
  field :public_id, type: String
  field :version,   type: String
  field :content,   type: Hash
  
  belongs_to :repository
end
