# frozen_string_literal: true

class DropOrphanRichBodyRows < ActiveRecord::Migration[8.1]
  def up
    execute "DELETE FROM action_text_rich_texts WHERE name = 'rich_body'"
    execute "DELETE FROM active_storage_attachments WHERE name = 'attachments' AND record_type = 'Bullet'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
