# frozen_string_literal: true

class Pending < ApplicationRecord
  include Bucketable
  belongs_to :user
  validates :user_id, uniqueness: true

  def self.pending_of(user)
    provision!(user).bullets.active
  end

  def self.pending_number_of(user)
    pending_of(user).count
  end

  def self.provision!(user)
    if (existing = user.pending)
      return existing if existing.bucket

      user.buckets.create!(bucketable: existing, name: Onboarding::PENDING_NAME, icon: Onboarding::PENDING_ICON)
      return existing.reload
    end

    record = user.create_pending!
    user.buckets.create!(bucketable: record, name: Onboarding::PENDING_NAME, icon: Onboarding::PENDING_ICON)
    record.reload
  end
end
