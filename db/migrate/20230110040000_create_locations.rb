class CreateLocations < ActiveRecord::Migration[5.2]
  def change
    create_table :locations do |t|
      t.string :name, null: false
      t.string :clarification
      t.datetime :discarded_at
      t.timestamps null: false
    end

    add_index :locations, :discarded_at
  end
end
