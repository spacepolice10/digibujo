# frozen_string_literal: true

module Bullet::Mentionable
  extend ActiveSupport::Concern

  MENTION_TYPES = [
    { attachable_class: Project, ids_attribute: :project_ids },
    { attachable_class: Person, ids_attribute: :person_ids }
  ].freeze

  included do
    has_many :bullet_projects, dependent: :destroy
    has_many :projects, through: :bullet_projects
    has_many :bullet_people, dependent: :destroy
    has_many :people, through: :bullet_people
  end

  def mentions
    @mentions ||= Bullet::Mentions.new(self)
  end

  def sync_mentions_from_body!(rich_text_record:)
    return if @syncing_mentions

    @syncing_mentions = true
    MENTION_TYPES.each do |config|
      attachables = rich_text_record.body.attachables.grep(config[:attachable_class])
      public_send("#{config[:ids_attribute]}=", attachables.map(&:id).uniq)
    end
  ensure
    @syncing_mentions = false
  end

  def editor_content
    attachables = (projects.to_a + people.to_a).uniq
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

  def editor_content_for_form
    editor_content.fragment.to_html.presence || ''
  end

  private

  def rich_text_content_record
    ActionText::RichText.find_by(record: self, name: 'body')
  end

  def attachable_ids_from_content_html(html, type)
    return [] if html.blank?

    ActionText::Content.new(html, canonicalize: false).attachables.grep(type).map(&:id)
  end
end

ActiveSupport.on_load(:action_text_rich_text) do
  after_save :sync_bullet_mentions_from_body, if: :bullet_body_changed?

  private

  def bullet_body_changed?
    record.is_a?(Bullet) && name == 'body' && saved_change_to_body?
  end

  def sync_bullet_mentions_from_body
    record.sync_mentions_from_body!(rich_text_record: self)
  end
end
