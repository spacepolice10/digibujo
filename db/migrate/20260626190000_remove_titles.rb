# frozen_string_literal: true

class RemoveTitles < ActiveRecord::Migration[8.1]
  def up
    bullet_ids = select_values("SELECT id FROM bullets WHERE bulletable_type = 'Title'")
    purge_bullets(bullet_ids) if bullet_ids.present?

    drop_table :titles
  end

  def down
    create_table :titles do |t|
      t.timestamps
    end
  end

  private

  def purge_bullets(bullet_ids)
    ids = bullet_ids.join(',')

    execute "DELETE FROM bullet_people WHERE bullet_id IN (#{ids})"
    execute "DELETE FROM bullet_projects WHERE bullet_id IN (#{ids})"
    execute "DELETE FROM activities WHERE subject_type = 'Bullet' AND subject_id IN (#{ids})"
    execute "DELETE FROM archives WHERE archivable_type = 'Bullet' AND archivable_id IN (#{ids})"
    execute "DELETE FROM pinned_entities WHERE pinnable_type = 'Bullet' AND pinnable_id IN (#{ids})"
    execute "DELETE FROM published_entities WHERE publishable_type = 'Bullet' AND publishable_id IN (#{ids})"
    execute "DELETE FROM search_records WHERE searchable_type = 'Bullet' AND searchable_id IN (#{ids})"
    execute "DELETE FROM action_text_rich_texts WHERE record_type = 'Bullet' AND record_id IN (#{ids})"
    execute "DELETE FROM active_storage_attachments WHERE record_type = 'Bullet' AND record_id IN (#{ids})"
    execute "DELETE FROM bullets WHERE id IN (#{ids})"
  end
end
