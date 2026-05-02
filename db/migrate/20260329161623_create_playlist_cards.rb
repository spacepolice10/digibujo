class CreatePlaylistCards < ActiveRecord::Migration[8.1]
  def change
    create_table :playlist_cards do |t|
      t.references :playlist, null: false, foreign_key: true
      t.references :card, null: false, foreign_key: true
      t.integer :position, null: false

      t.timestamps
    end

    add_index :playlist_cards, [:playlist_id, :bullet_id], unique: true
    add_index :playlist_cards, [:playlist_id, :position]
  end
end
