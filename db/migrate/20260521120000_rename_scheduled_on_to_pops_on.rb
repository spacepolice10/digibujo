# frozen_string_literal: true

class RenameScheduledOnToPopsOn < ActiveRecord::Migration[8.1]
  def up
    rename_column :bullets, :scheduled_on, :pops_on
    rename_index :bullets, "index_bullets_on_user_id_and_scheduled_on", "index_bullets_on_user_id_and_pops_on"

    execute <<~SQL.squish
      UPDATE bullet_activities SET action = 'popped' WHERE action = 'scheduled'
    SQL
  end
end
