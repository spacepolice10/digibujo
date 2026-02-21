class CreateCardTags < ActiveRecord::Migration[8.1]
  def change
    create_table :card_tags do |t|
      t.references :card, null: false, foreign_key: true
      t.references :tag, null: false, foreign_key: true

      t.timestamps
    end

    add_index :card_tags, [ :card_id, :tag_id ], unique: true
  end
end
