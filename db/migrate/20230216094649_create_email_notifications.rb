class CreateEmailNotifications < ActiveRecord::Migration[5.2]
  def change
    create_table :email_notifications do |t|
      t.text :body, null: false, default: ''
      t.string :path, null: false
      t.string :format, default: 'html'
      t.string :handler, null: false
      t.boolean :default, default: false
      t.timestamps
    end

    add_index :email_notifications, :path, using: 'btree'
  end
end
