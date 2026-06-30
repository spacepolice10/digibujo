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
