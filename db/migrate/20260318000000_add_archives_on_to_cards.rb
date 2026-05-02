class AddArchivesOnToCards < ActiveRecord::Migration[8.1]
  def change
    add_column :bullets, :archives_on, :date
    add_index :bullets, [ :user_id, :archives_on ]
  end
end
