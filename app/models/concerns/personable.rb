# frozen_string_literal: true

module Personable
  extend ActiveSupport::Concern

  included do
    has_many :bullet_people, dependent: :destroy
    has_many :people, through: :bullet_people
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

  def apply_people_tags_from_content!(rich_text_record: nil)
    return if @applying_people_tags_from_content

    record = rich_text_record || rich_text_content_record
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

  def rich_text_content_record
    ActionText::RichText.find_by(record: self, name: 'body')
  end

  def people_attachables_from_content(record)
    record.body.attachables.grep(Person)
  end

  def content_removed_person_attachments?(record)
    old_body, new_body = record.saved_change_to_body
    old_attachables = ActionText::Content.new(old_body.to_s).attachables.grep(Person)
    new_attachables = ActionText::Content.new(new_body.to_s).attachables.grep(Person)
    old_attachables.any? && new_attachables.empty?
  end

  def stamp_triaged!
    update!(triaged_at: triaged_at || Time.current) unless triaged_at?
  end
end
