# frozen_string_literal: true

class FoldRichBodyIntoBodyAndRepointAttachments < ActiveRecord::Migration[8.1]
  def up
    fold_note_rich_bodies
    migrate_non_note_rich_content
    repoint_note_attachments_inline
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "rich_body has been folded into body; cannot reverse"
  end

  private

  def fold_note_rich_bodies
    rows = select_all(<<~SQL.squish)
      SELECT id, record_id FROM action_text_rich_texts
       WHERE name = 'rich_body' AND record_type = 'Bullet'
         AND record_id IN (SELECT id FROM bullets WHERE bulletable_type = 'Note')
    SQL

    rows.each do |row|
      rich_html = select_value(<<~SQL.squish)
        SELECT body FROM action_text_rich_texts WHERE id = #{row["id"]}
      SQL

      body_html = select_value(<<~SQL.squish)
        SELECT body FROM action_text_rich_texts
         WHERE name = 'body' AND record_type = 'Bullet' AND record_id = #{row["record_id"]}
      SQL

      folded = if body_html.to_s.strip.present?
                 "#{body_html}<hr>#{rich_html}"
               else
                 rich_html.to_s
               end

      existing = select_value(<<~SQL.squish)
        SELECT id FROM action_text_rich_texts
         WHERE name = 'body' AND record_type = 'Bullet' AND record_id = #{row["record_id"]}
      SQL

      if existing
        execute <<~SQL.squish
          UPDATE action_text_rich_texts SET body = #{quote(folded)}, updated_at = CURRENT_TIMESTAMP WHERE id = #{existing}
        SQL
      else
        execute <<~SQL.squish
          INSERT INTO action_text_rich_texts (record_type, record_id, name, body, created_at, updated_at)
          VALUES ('Bullet', #{row["record_id"]}, 'body', #{quote(folded)}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        SQL
      end

      execute "DELETE FROM action_text_rich_texts WHERE id = #{row["id"]}"
    end
  end

  def migrate_non_note_rich_content
    bullet_rows = select_all(<<~SQL.squish)
      SELECT b.id, b.user_id, b.bucket_id, b.created_at, b.updated_at
        FROM bullets b
        WHERE b.bulletable_type != 'Note'
          AND (
            EXISTS (SELECT 1 FROM action_text_rich_texts r
                     WHERE r.record_type = 'Bullet' AND r.record_id = b.id AND r.name = 'rich_body')
            OR EXISTS (SELECT 1 FROM active_storage_attachments a
                        WHERE a.record_type = 'Bullet' AND a.record_id = b.id AND a.name = 'attachments')
          )
    SQL

    bullet_rows.each do |brow|
      rich_html = select_value(<<~SQL.squish).to_s
        SELECT body FROM action_text_rich_texts
         WHERE name = 'rich_body' AND record_type = 'Bullet' AND record_id = #{brow["id"]}
      SQL

      embeds = attachment_embeds_for("Bullet", brow["id"])

      new_body = [rich_html, embeds].compact.join.strip

      next if new_body.blank?

      execute <<~SQL.squish
        INSERT INTO notes DEFAULT VALUES
      SQL
      note_id = select_value("SELECT last_insert_rowid()")

      execute <<~SQL.squish
        INSERT INTO bullets (user_id, bucket_id, bulletable_id, bulletable_type,
                            pops_on, last_migration, migrated_at,
                            created_at, updated_at)
        VALUES (#{brow["user_id"]}, #{brow["bucket_id"]}, #{note_id}, 'Note',
                NULL, '{}', NULL,
                #{quote(brow["created_at"])}, #{quote(brow["updated_at"])})
      SQL
      new_bullet_id = select_value("SELECT last_insert_rowid()")

      execute <<~SQL.squish
        INSERT INTO action_text_rich_texts (record_type, record_id, name, body, created_at, updated_at)
        VALUES ('Bullet', #{new_bullet_id}, 'body', #{quote(new_body)}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      SQL

      execute <<~SQL.squish
        DELETE FROM action_text_rich_texts WHERE name = 'rich_body'
          AND record_type = 'Bullet' AND record_id = #{brow["id"]}
      SQL

      original_body = select_value(<<~SQL.squish).to_s
        SELECT body FROM action_text_rich_texts
         WHERE name = 'body' AND record_type = 'Bullet' AND record_id = #{brow["id"]}
      SQL
      if original_body.strip.blank?
        execute <<~SQL.squish
          INSERT INTO archives (archivable_type, archivable_id, user_id, created_at, updated_at)
          VALUES ('Bullet', #{brow["id"]}, #{brow["user_id"]}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        SQL
      end

      delete_bullet_attachments(brow["id"])
    end
  end

  def repoint_note_attachments_inline
    note_bullet_rows = select_all(<<~SQL.squish)
      SELECT b.id AS bullet_id, b.user_id
        FROM bullets b
        WHERE b.bulletable_type = 'Note'
          AND EXISTS (SELECT 1 FROM active_storage_attachments a
                        WHERE a.record_type = 'Bullet' AND a.record_id = b.id AND a.name = 'attachments')
    SQL

    note_bullet_rows.each do |nrow|
      embeds = attachment_embeds_for("Bullet", nrow["bullet_id"])
      next if embeds.blank?

      body_html = select_value(<<~SQL.squish).to_s
        SELECT body FROM action_text_rich_texts
         WHERE name = 'body' AND record_type = 'Bullet' AND record_id = #{nrow["bullet_id"]}
      SQL
      new_body = [body_html, embeds].compact.join.strip

      existing = select_value(<<~SQL.squish)
        SELECT id FROM action_text_rich_texts
         WHERE name = 'body' AND record_type = 'Bullet' AND record_id = #{nrow["bullet_id"]}
      SQL
      if existing
        execute <<~SQL.squish
          UPDATE action_text_rich_texts SET body = #{quote(new_body)}, updated_at = CURRENT_TIMESTAMP WHERE id = #{existing}
        SQL
      else
        execute <<~SQL.squish
          INSERT INTO action_text_rich_texts (record_type, record_id, name, body, created_at, updated_at)
          VALUES ('Bullet', #{nrow["bullet_id"]}, 'body', #{quote(new_body)}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        SQL
      end

      delete_bullet_attachments(nrow["bullet_id"])
    end
  end

  def delete_bullet_attachments(bullet_id)
    execute <<~SQL.squish
      DELETE FROM active_storage_attachments
       WHERE record_type = 'Bullet' AND record_id = #{bullet_id} AND name = 'attachments'
    SQL
  end

  def attachment_embeds_for(record_type, record_id)
    blobs = select_all(<<~SQL.squish).to_a
      SELECT a.id AS attachment_id, a.blob_id AS blob_id
        FROM active_storage_attachments a
       WHERE a.record_type = #{quote(record_type)} AND a.record_id = #{record_id} AND a.name = 'attachments'
    SQL

    return if blobs.empty?

    embeds = blobs.map do |blob|
      blob_record = ActiveStorage::Blob.find_by(id: blob["blob_id"])
      next unless blob_record

      ActionText::Attachment.from_attachable(blob_record).to_html
    end.compact

    embeds.join
  rescue StandardError => e
    say "attachment_embeds_for(#{record_type}, #{record_id}) failed: #{e.message}"
    ""
  end

  def quote(value)
    connection.quote(value)
  end
end
