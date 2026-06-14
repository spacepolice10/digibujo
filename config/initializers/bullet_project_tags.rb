# frozen_string_literal: true

ActiveSupport.on_load(:action_text_rich_text) do
  after_save :sync_bullet_project_tags_from_body, if: :bullet_content_body_changed?

  private

  def bullet_content_body_changed?
    record.is_a?(Bullet) && name == "content" && saved_change_to_body?
  end

  def sync_bullet_project_tags_from_body
    record.apply_project_tags_from_content!
  end
end
