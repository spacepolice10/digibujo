# frozen_string_literal: true

module Personable
  extend ActiveSupport::Concern

  PERSON_ATTACHMENT_SELECTOR = 'action-text-attachment[content-type="application/vnd.actiontext.person"]'

  included do
    has_many :bullet_people, dependent: :destroy
    has_many :people, through: :bullet_people

    after_save :apply_people_tags_from_content!
  end

  def tag_person!(person_id:)
    person = user.people.find(person_id)
    bullet_people.find_or_create_by!(person: person)
    stamp_triaged!
    BulletActivityRecorder.record_person_tagged!(bullet: self)
  end

  def untag_person!(person_id:)
    bullet_people.where(person_id: person_id).destroy_all
    BulletActivityRecorder.record_person_untagged!(bullet: self)
  end

  def untag_all_people!
    return if people.none?

    bullet_people.destroy_all
    BulletActivityRecorder.record_person_untagged!(bullet: self)
  end

  def apply_people_tags_from_content!
    return if @applying_people_tags_from_content

    record = rich_text_record
    return unless record

    person_attachables = people_attachables_from_content(record)
    if person_attachables.any?
      @applying_people_tags_from_content = true
      self.person_ids = person_attachables.map(&:id).uniq
      stamp_triaged!
    elsif record.saved_change_to_body? && content_removed_person_attachments?(record)
      self.person_ids = []
    end
  ensure
    @applying_people_tags_from_content = false
  end



  private

  def rich_text_record
    ActionText::RichText.find_by(record: self, name: "content")
  end

  def people_attachables_from_content(record)
    attachables = record.body.attachables.grep(Person)
    return attachables if attachables.any?

    people_from_attachment_sgids(record)
  end

  def people_from_attachment_sgids(record)
    person_attachment_nodes(record).filter_map do |node|
      sgid = node["sgid"]
      next if sgid.blank?

      Person.from_attachable_sgid(sgid)
    rescue ActiveRecord::RecordNotFound
      nil
    end
  end

  def content_removed_person_attachments?(record)
    old_body, new_body = record.saved_change_to_body
    old_nodes = Nokogiri::HTML.fragment(old_body.to_s).css(PERSON_ATTACHMENT_SELECTOR)
    new_nodes = Nokogiri::HTML.fragment(new_body.to_s).css(PERSON_ATTACHMENT_SELECTOR)
    old_nodes.any? && new_nodes.empty?
  end

  def person_attachment_nodes(record)
    html = record.body_before_type_cast.to_s
    return [] if html.blank?

    Nokogiri::HTML.fragment(html).css(PERSON_ATTACHMENT_SELECTOR)
  end

  def stamp_triaged!
    update!(triaged_at: triaged_at || Time.current) unless triaged_at?
  end

  def person_ids_from_editor_html(html)
    return [] if html.blank?

    Nokogiri::HTML.fragment(html).css(PERSON_ATTACHMENT_SELECTOR).filter_map do |node|
      sgid = node["sgid"]
      next if sgid.blank?

      Person.from_attachable_sgid(sgid).id
    rescue ActiveRecord::RecordNotFound
      nil
    end
  end
end
