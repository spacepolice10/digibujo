# frozen_string_literal: true

# Body rich texts used to hang off Bullet (has_rich_text :body on Bullet).
# Ownership moved to the delegated types (Task/Note/Event/Voice), so repoint
# existing rows at the bulletable. Embedded Active Storage attachments belong
# to the ActionText::RichText row itself and need no repointing.
class MoveBulletBodyRichTextsToBulletables < ActiveRecord::Migration[8.1]
  BULLETABLE_TYPES = %w[Task Note Event Voice].freeze

  def up
    execute <<~SQL.squish
      UPDATE action_text_rich_texts
         SET record_type = (SELECT b.bulletable_type FROM bullets b WHERE b.id = action_text_rich_texts.record_id),
             record_id   = (SELECT b.bulletable_id   FROM bullets b WHERE b.id = action_text_rich_texts.record_id)
       WHERE name = 'body'
         AND record_type = 'Bullet'
         AND EXISTS (
           SELECT 1 FROM bullets b
            WHERE b.id = action_text_rich_texts.record_id
              AND b.bulletable_id IS NOT NULL
              AND b.bulletable_type IS NOT NULL
         )
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE action_text_rich_texts
         SET record_id = (
               SELECT b.id FROM bullets b
                WHERE b.bulletable_type = action_text_rich_texts.record_type
                  AND b.bulletable_id = action_text_rich_texts.record_id
             ),
             record_type = 'Bullet'
       WHERE name = 'body'
         AND record_type IN (#{BULLETABLE_TYPES.map { |type| connection.quote(type) }.join(', ')})
         AND EXISTS (
           SELECT 1 FROM bullets b
            WHERE b.bulletable_type = action_text_rich_texts.record_type
              AND b.bulletable_id = action_text_rich_texts.record_id
         )
    SQL
  end
end
