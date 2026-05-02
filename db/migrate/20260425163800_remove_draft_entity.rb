class RemoveDraftEntity < ActiveRecord::Migration[8.1]
  class MigrationCard < ApplicationRecord
    self.table_name = "bullets"
  end

  class MigrationTask < ApplicationRecord
    self.table_name = "tasks"
  end

  def up
    MigrationCard.where(cardable_type: "Draft").find_each do |card|
      task = MigrationTask.create!
      card.update_columns(cardable_type: "Task", cardable_id: task.id, updated_at: Time.current)
    end

    drop_table :drafts, if_exists: true
  end

  def down
    create_table :drafts do |t|
    end

    raise ActiveRecord::IrreversibleMigration, "Cannot restore original Draft records after conversion to Task."
  end
end
