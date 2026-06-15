# frozen_string_literal: true

module Projectable
  extend ActiveSupport::Concern

  included do
    has_many :bullet_projects, dependent: :destroy
    has_many :projects, through: :bullet_projects
  end

  def tag_project!(project_id:)
    project = user.projects.find(project_id)
    bullet_projects.find_or_create_by!(project: project)
    stamp_triaged!
    BulletActivityRecorder.record_project_tagged!(bullet: self)
  end

  def untag_project!(project_id:)
    bullet_projects.where(project_id: project_id).destroy_all
    BulletActivityRecorder.record_project_untagged!(bullet: self)
  end

  def untag_all_projects!
    return if projects.none?

    bullet_projects.destroy_all
    BulletActivityRecorder.record_project_untagged!(bullet: self)
  end

  def apply_project_tags_from_content!(rich_text_record: nil)
    return if @applying_project_tags_from_content

    record = rich_text_record || rich_text_content_record
    return unless record

    project_attachables = project_attachables_from_content(record)

    if project_attachables.any?
      @applying_project_tags_from_content = true
      self.project_ids = project_attachables.map(&:id).uniq
      stamp_triaged!
    elsif record.saved_change_to_body? && content_removed_project_attachments?(record)
      self.project_ids = []
    end
  ensure
    @applying_project_tags_from_content = false
  end

  def editor_content(default_projects: [], default_people: [])
    person_attachables = (respond_to?(:people) ? people.to_a : []) + Array(default_people).compact
    attachables = (projects.to_a + Array(default_projects).compact + person_attachables).uniq
    html = rich_text_content_record&.body_before_type_cast.to_s.dup
    existing_project_ids = attachable_ids_from_content_html(html, Project)
    existing_person_ids = attachable_ids_from_content_html(html, Person)

    attachables.each do |attachable|
      next if attachable.is_a?(Project) && existing_project_ids.include?(attachable.id)
      next if attachable.is_a?(Person) && existing_person_ids.include?(attachable.id)

      attachment_html = ActionText::Attachment.from_attachables([attachable]).first.to_html
      html = [html.presence, attachment_html].compact.join("\n")
    end

    ActionText::Content.new(html, canonicalize: false)
  end

  private

  def rich_text_content_record
    ActionText::RichText.find_by(record: self, name: 'body')
  end

  def project_attachables_from_content(record)
    record.body.attachables.grep(Project)
  end

  def content_removed_project_attachments?(record)
    old_body, new_body = record.saved_change_to_body
    old_attachables = ActionText::Content.new(old_body.to_s).attachables.grep(Project)
    new_attachables = ActionText::Content.new(new_body.to_s).attachables.grep(Project)
    old_attachables.any? && new_attachables.empty?
  end

  def attachable_ids_from_content_html(html, type)
    return [] if html.blank?

    ActionText::Content.new(html, canonicalize: false).attachables.grep(type).map(&:id)
  end

  def stamp_triaged!
    update!(triaged_at: triaged_at || Time.current) unless triaged_at?
  end
end
