class RemoveDraftsAndMakeCardableOptional < ActiveRecord::Migration[8.1]
  def up
    # Make cardable columns nullable first
    change_column_null :cards, :cardable_type, true
    change_column_null :cards, :cardable_id, true

    # Nullify cardable references for existing Draft cards
    execute <<~SQL
      UPDATE cards SET cardable_type = NULL, cardable_id = NULL WHERE cardable_type = 'Draft'
    SQL

    # Delete orphaned draft records and drop table
    execute "DELETE FROM drafts"
    drop_table :drafts
  end

  def down
    create_table :drafts do |t|
    end

    change_column_null :cards, :cardable_type, false, "Draft"
    change_column_null :cards, :cardable_id, false
  end
end
