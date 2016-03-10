class CreateRules < ActiveRecord::Migration
  def change
    create_table :rules do |t|
      t.string :name
      t.string :version

      t.timestamps null: false
    end
  end
end
