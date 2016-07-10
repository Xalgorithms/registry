class Repository
  include Mongoid::Document

  field :url,       type: String
  field :public_id, type: String
  
  has_many :rules
end
