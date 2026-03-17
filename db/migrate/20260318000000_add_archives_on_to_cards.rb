class AddArchivesOnToCards < ActiveRecord::Migration[8.1]
  def change
    add_column :cards, :archives_on, :date
    add_index :cards, [ :user_id, :archives_on ]
  end
end
