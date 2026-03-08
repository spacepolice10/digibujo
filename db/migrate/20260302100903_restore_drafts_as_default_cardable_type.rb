class RestoreDraftsAsDefaultCardableType < ActiveRecord::Migration[8.1]
  def up
    create_table :drafts do |t|
    end

    # Create a Draft record for each card with NULL cardable and link them
    execute <<~SQL
      INSERT INTO drafts (rowid) SELECT id FROM cards WHERE cardable_type IS NULL
    SQL
    execute <<~SQL
      UPDATE cards SET cardable_type = 'Draft', cardable_id = id WHERE cardable_type IS NULL
    SQL

    change_column_null :cards, :cardable_type, false
    change_column_null :cards, :cardable_id, false
  end

  def down
    change_column_null :cards, :cardable_type, true
    change_column_null :cards, :cardable_id, true

    execute <<~SQL
      UPDATE cards SET cardable_type = NULL, cardable_id = NULL WHERE cardable_type = 'Draft'
    SQL

    drop_table :drafts
  end
end
