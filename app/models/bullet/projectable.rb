# frozen_string_literal: true

module Bullet::Projectable
  extend ActiveSupport::Concern

  included do
    has_many :bullet_projects, dependent: :destroy
    has_many :projects, through: :bullet_projects
  end

  def sync_projects_from_body!
    return unless bulletable.is_a?(Bulletable)
    return if @syncing_projects

    @syncing_projects = true
    content = bulletable.body.body
    self.project_ids = content ? content.attachables.grep(Project).map(&:id).uniq : []
  ensure
    @syncing_projects = false
  end
end

ActiveSupport.on_load(:action_text_rich_text) do
  after_save :sync_bullet_projects_from_body, if: :bulletable_body_changed?

  private

  def bulletable_body_changed?
    record.is_a?(Bulletable) && name == 'body' && saved_change_to_body?
  end

  def sync_bullet_projects_from_body
    record.bullet&.sync_projects_from_body!
  end
end
