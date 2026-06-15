# frozen_string_literal: true

ActiveSupport.on_load(:action_text_rich_text) do
  after_save :sync_bullet_tags_from_body, if: :bullet_body_changed?

  private

  def bullet_body_changed?
    record.is_a?(Bullet) && name == 'body' && saved_change_to_body?
  end

  def sync_bullet_tags_from_body
    record.apply_project_tags_from_content!(rich_text_record: self)
    record.apply_people_tags_from_content!(rich_text_record: self)
  end
end
