class AddLocationRelationToSchedule < ActiveRecord::Migration[5.2]
  def change
    rename_column :schedules, :location, :location_name
    add_reference :schedules, :location, index: true, foreign_key: true
  end
end
