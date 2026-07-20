# frozen_string_literal: true

module Bullet::Projectable
  extend ActiveSupport::Concern

  included do
    has_many :bullet_projects, dependent: :destroy
    has_many :projects, through: :bullet_projects
  end

  def sync_projects_from_body!
    return unless bulletable.is_a?(Note)
    return if @syncing_projects

    @syncing_projects = true
    attachables = bulletable.body.body.attachables.grep(Project)
    self.project_ids = attachables.map(&:id).uniq
  ensure
    @syncing_projects = false
  end
end

ActiveSupport.on_load(:action_text_rich_text) do
  after_save :sync_bullet_projects_from_body, if: :note_body_changed?

  private

  def note_body_changed?
    record.is_a?(Note) && name == 'body' && saved_change_to_body?
  end

  def sync_bullet_projects_from_body
    record.bullet&.sync_projects_from_body!
  end
end
