# frozen_string_literal: true

# Body rich texts hang off the bulletable types (each has_rich_text :body via
# the Bulletable concern). Ownership moves to Bullet proper, so the four types
# share one rich text per bullet. Repoint existing rows at the owning bullet.
class MoveBodyRichTextsToBullets < ActiveRecord::Migration[8.1]
  BULLETABLE_TYPES = %w[Task Note Event Voice].freeze

  def up
    execute <<~SQL.squish
      UPDATE action_text_rich_texts
         SET record_type = 'Bullet',
             record_id   = (
               SELECT b.id FROM bullets b
                WHERE b.bulletable_type = action_text_rich_texts.record_type
                  AND b.bulletable_id = action_text_rich_texts.record_id
                LIMIT 1
             )
       WHERE name = 'body'
         AND record_type IN (#{quoted_types})
         AND EXISTS (
           SELECT 1 FROM bullets b
            WHERE b.bulletable_type = action_text_rich_texts.record_type
              AND b.bulletable_id = action_text_rich_texts.record_id
         )
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE action_text_rich_texts
         SET record_type = (SELECT b.bulletable_type FROM bullets b WHERE b.id = action_text_rich_texts.record_id),
             record_id   = (SELECT b.bulletable_id   FROM bullets b WHERE b.id = action_text_rich_texts.record_id)
       WHERE name = 'body'
         AND record_type = 'Bullet'
         AND EXISTS (
           SELECT 1 FROM bullets b
            WHERE b.id = action_text_rich_texts.record_id
         )
    SQL
  end

  private

  def quoted_types
    BULLETABLE_TYPES.map { |type| connection.quote(type) }.join(', ')
  end
end