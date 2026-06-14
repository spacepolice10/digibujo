# frozen_string_literal: true

class BulletProject < ApplicationRecord
  belongs_to :bullet
  belongs_to :project

  validate :same_user

  private

  def same_user
    return if bullet.user_id == project.user_id

    errors.add(:base, "bullet and project must belong to the same user")
  end
end
