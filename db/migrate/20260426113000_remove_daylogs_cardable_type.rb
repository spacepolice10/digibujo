class RemoveDaylogsCardableType < ActiveRecord::Migration[8.1]
  class MigrationCard < ApplicationRecord
    self.table_name = "cards"
  end

  class MigrationNote < ApplicationRecord
    self.table_name = "notes"
  end

  def up
    migrate_daylog_cards_to_notes
    drop_table :daylogs if table_exists?(:daylogs)
  end

  def down
    create_table :daylogs do |t|
      t.integer :mood
    end

    raise ActiveRecord::IrreversibleMigration, "Cannot restore original Daylog records once migrated to Note."
  end

  private

  def migrate_daylog_cards_to_notes
    return unless table_exists?(:cards) && table_exists?(:notes)

    MigrationCard.where(cardable_type: "Daylog").find_each do |card|
      note = MigrationNote.create!
      card.update_columns(cardable_type: "Note", cardable_id: note.id, updated_at: Time.current)
    end
  end
end
