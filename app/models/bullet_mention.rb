# frozen_string_literal: true

class BulletMention < ApplicationRecord
  belongs_to :bullet
  belongs_to :mention

  validate :same_user

  private

  def same_user
    return if bullet.user_id == mention.user_id

    errors.add(:base, "bullet and mention must belong to the same user")
  end
end
