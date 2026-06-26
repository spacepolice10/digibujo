# frozen_string_literal: true

class BulletPerson < ApplicationRecord
  belongs_to :bullet
  belongs_to :person

  validate :same_user

  private

  def same_user
    return if bullet.user_id == person.user_id

    errors.add(:base, 'bullet and person must belong to the same user')
  end
end
