class RelinkCardRichTextToBullet < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE action_text_rich_texts
      SET record_type = 'Bullet'
      WHERE record_type = 'Card'
    SQL

    execute <<~SQL
      UPDATE active_storage_attachments
      SET record_type = 'Bullet'
      WHERE record_type = 'Card'
    SQL
  end

  def down
    execute <<~SQL
      UPDATE action_text_rich_texts
      SET record_type = 'Card'
      WHERE record_type = 'Bullet'
    SQL

    execute <<~SQL
      UPDATE active_storage_attachments
      SET record_type = 'Card'
      WHERE record_type = 'Bullet'
    SQL
  end
end
