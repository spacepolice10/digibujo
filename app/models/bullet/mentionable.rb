# frozen_string_literal: true

module Bullet::Mentionable
  extend ActiveSupport::Concern

  included do
    has_many :bullet_mentions, dependent: :destroy
    has_many :mentions, through: :bullet_mentions
  end

  def add_mention!(mention_id:)
    mention = user.mentions.find(mention_id)
    bullet_mentions.find_or_create_by!(mention: mention)
    association(:mentions).reset
    record_activity!(mention.kind_config.fetch(:activity_mentioned))
  end

  def remove_mention!(mention_id:)
    join = bullet_mentions.find_by(mention_id: mention_id)
    return unless join

    mention = join.mention
    join.destroy!
    association(:mentions).reset
    record_activity!(mention.kind_config.fetch(:activity_unmentioned))
  end

  def clear_mentions!
    return if bullet_mentions.none?

    kinds = mentions.map(&:kind).uniq
    bullet_mentions.destroy_all
    association(:mentions).reset
    kinds.each do |kind|
      record_activity!(Mention::KIND.fetch(kind).fetch(:activity_unmentioned))
    end
  end

  def sync_mentions_from_body!
    return if @syncing_mentions

    @syncing_mentions = true
    attachables = bulletable.body.body.attachables.grep(Mention)
    self.mention_ids = attachables.map(&:id).uniq
  ensure
    @syncing_mentions = false
  end
end

ActiveSupport.on_load(:action_text_rich_text) do
  after_save :sync_bullet_mentions_from_body, if: :bulletable_body_changed?

  private

  def bulletable_body_changed?
    record.is_a?(Bulletable) && name == 'body' && saved_change_to_body?
  end

  def sync_bullet_mentions_from_body
    record.bullet&.sync_mentions_from_body!
  end
end
