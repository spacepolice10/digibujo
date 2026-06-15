# frozen_string_literal: true

class SplitBulletContent < ActiveRecord::Migration[8.1]
  class MigrationBullet < ApplicationRecord
    self.table_name = 'bullets'
  end

  class MigrationRichText < ApplicationRecord
    self.table_name = 'action_text_rich_texts'
  end

  def up
    rename_content_to_body

    MigrationRichText.where(record_type: 'Bullet', name: 'content').find_each do |rich_text|
      extract_blob_attachments!(rich_text)
    end
  end

  def down
    MigrationRichText.where(record_type: 'Bullet', name: 'body').find_each do |rich_text|
      restore_blob_attachments!(rich_text)
    end

    MigrationRichText.where(record_type: 'Bullet', name: 'rich_body').delete_all
    MigrationRichText.where(record_type: 'Bullet', name: 'body').update_all(name: 'content')
  end

  private

  def rename_content_to_body
    MigrationRichText.where(record_type: 'Bullet', name: 'content').update_all(name: 'body')
  end

  def extract_blob_attachments!(rich_text)
    return if rich_text.body.blank?

    fragment = ActionText::Fragment.wrap(rich_text.body)
    blob_attachables = ActionText::Content.new(fragment.to_html).attachables.grep(ActiveStorage::Blob)
    return if blob_attachables.empty?

    bullet = MigrationBullet.find_by(id: rich_text.record_id)
    return unless bullet

    blob_attachables.uniq.each do |blob|
      next if attachment_exists?(bullet.id, blob.id)

      execute <<~SQL.squish
        INSERT INTO active_storage_attachments (name, record_type, record_id, blob_id, created_at)
        VALUES ('attachments', 'Bullet', #{bullet.id}, #{blob.id}, CURRENT_TIMESTAMP)
      SQL
    end

    stripped_html = strip_blob_attachments(fragment.to_html)
    rich_text.update_column(:body, stripped_html)
  end

  def restore_blob_attachments!(rich_text)
    bullet = MigrationBullet.find_by(id: rich_text.record_id)
    return unless bullet

    attachment_rows(bullet.id).each do |row|
      blob = ActiveStorage::Blob.find_by(id: row['blob_id'])
      next unless blob

      html = rich_text.body.to_s
      attachment_html = ActionText::Attachment.from_attachables([blob]).first.to_html
      rich_text.update_column(:body, [html.presence, attachment_html].compact.join("\n"))
    end

    execute <<~SQL.squish
      DELETE FROM active_storage_attachments
      WHERE record_type = 'Bullet' AND record_id = #{bullet.id} AND name = 'attachments'
    SQL
  end

  def strip_blob_attachments(html)
    ActionText::Fragment.wrap(html).replace(ActionText::Attachment.tag_name) do |node|
      attachment = ActionText::Attachment.from_node(node)
      attachment.attachable.is_a?(ActiveStorage::Blob) ? '' : node
    end.to_html
  end

  def attachment_exists?(bullet_id, blob_id)
    attachment_rows(bullet_id).any? { |row| row['blob_id'].to_i == blob_id.to_i }
  end

  def attachment_rows(bullet_id)
    select_all <<~SQL.squish
      SELECT blob_id FROM active_storage_attachments
      WHERE record_type = 'Bullet' AND record_id = #{bullet_id} AND name = 'attachments'
    SQL
  end
end
