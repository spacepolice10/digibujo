# frozen_string_literal: true

module Projectable
  extend ActiveSupport::Concern

  PROJECT_ATTACHMENT_SELECTOR = 'action-text-attachment[content-type="application/vnd.actiontext.project"]'

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

  def apply_project_tags_from_content!
    return if @applying_project_tags_from_content

    record = rich_text_record
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
    html = rich_text_record&.body_before_type_cast.to_s.dup
    existing_project_ids = project_ids_from_editor_html(html)
    existing_person_ids = respond_to?(:person_ids_from_editor_html) ? person_ids_from_editor_html(html) : []

    attachables.each do |attachable|
      next if attachable.is_a?(Project) && existing_project_ids.include?(attachable.id)
      next if attachable.is_a?(Person) && existing_person_ids.include?(attachable.id)

      attachment_html = ActionText::Attachment.from_attachables([ attachable ]).first.to_html
      html = [ html.presence, attachment_html ].compact.join("\n")
    end

    ActionText::Content.new(html, canonicalize: false)
  end

  private

  def rich_text_record
    ActionText::RichText.find_by(record: self, name: "content")
  end

  def project_attachables_from_content(record)
    attachables = record.body.attachables.grep(Project)
    return attachables if attachables.any?

    projects_from_attachment_sgids(record)
  end

  def projects_from_attachment_sgids(record)
    project_attachment_nodes(record).filter_map do |node|
      sgid = node["sgid"]
      next if sgid.blank?

      Project.from_attachable_sgid(sgid)
    rescue ActiveRecord::RecordNotFound
      nil
    end
  end

  def content_removed_project_attachments?(record)
    old_body, new_body = record.saved_change_to_body
    old_nodes = Nokogiri::HTML.fragment(old_body.to_s).css(PROJECT_ATTACHMENT_SELECTOR)
    new_nodes = Nokogiri::HTML.fragment(new_body.to_s).css(PROJECT_ATTACHMENT_SELECTOR)
    old_nodes.any? && new_nodes.empty?
  end

  def project_attachment_nodes(record)
    html = record.body_before_type_cast.to_s
    return [] if html.blank?

    Nokogiri::HTML.fragment(html).css(PROJECT_ATTACHMENT_SELECTOR)
  end

  def stamp_triaged!
    update!(triaged_at: triaged_at || Time.current) unless triaged_at?
  end

  def project_ids_from_editor_html(html)
    return [] if html.blank?

    Nokogiri::HTML.fragment(html).css(PROJECT_ATTACHMENT_SELECTOR).filter_map do |node|
      sgid = node["sgid"]
      next if sgid.blank?

      Project.from_attachable_sgid(sgid).id
    rescue ActiveRecord::RecordNotFound
      nil
    end
  end
end
