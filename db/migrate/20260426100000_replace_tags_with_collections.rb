class ReplaceTagsWithCollections < ActiveRecord::Migration[8.1]
  def up
    create_table :collections do |t|
      t.string :name, null: false
      t.string :colour
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end
    add_index :collections, [:user_id, :name], unique: true

    add_reference :cards, :collection, foreign_key: true

    execute <<~SQL
      INSERT INTO collections (user_id, name, colour, created_at, updated_at)
      SELECT tags.user_id, tags.name, tags.colour, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM tags
      GROUP BY tags.user_id, tags.name
    SQL

    execute <<~SQL
      UPDATE cards
      SET collection_id = (
        SELECT collections.id
        FROM card_tags
        INNER JOIN tags ON tags.id = card_tags.tag_id
        INNER JOIN collections ON collections.user_id = tags.user_id AND collections.name = tags.name
        WHERE card_tags.card_id = cards.id
        ORDER BY card_tags.id ASC
        LIMIT 1
      )
      WHERE EXISTS (SELECT 1 FROM card_tags WHERE card_tags.card_id = cards.id)
    SQL

    remove_foreign_key :card_tags, :cards
    remove_foreign_key :card_tags, :tags
    drop_table :card_tags
    drop_table :tags
  end

  def down
    create_table :tags do |t|
      t.string :name, null: false
      t.references :user, null: false, foreign_key: true
      t.string :colour
      t.timestamps
    end
    add_index :tags, [:user_id, :name], unique: true

    create_table :card_tags do |t|
      t.references :card, null: false, foreign_key: true
      t.references :tag, null: false, foreign_key: true
      t.timestamps
    end
    add_index :card_tags, [:card_id, :tag_id], unique: true

    remove_reference :cards, :collection, foreign_key: true
    drop_table :collections
  end
end
