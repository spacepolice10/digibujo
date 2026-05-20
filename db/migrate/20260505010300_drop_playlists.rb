class DropPlaylists < ActiveRecord::Migration[8.1]
  def change
    drop_table :playlist_cards do |t|
      t.references :playlist, null: false, foreign_key: true
      t.references :bullet, null: false, foreign_key: true
      t.integer :position
      t.timestamps
    end

    drop_table :playlists do |t|
      t.references :user, null: false, foreign_key: true
      t.string :colour, null: false
      t.string :icon, null: false
      t.timestamps
    end
  end
end
