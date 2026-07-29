# frozen_string_literal: true

class Pending < ApplicationRecord
  include Bucketable

  belongs_to :user

  validates :user_id, uniqueness: true

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

  # External captures in Pending, plus current monthlylog bullets planned for `date`.
  def self.inbox_for(user, date: Date.current)
    pending = provision!(user)
    relation = user.bullets.active.where(bucket_id: pending.bucket.id)

    monthly_bucket = user.monthlylogs.covering(date).take&.bucket
    if monthly_bucket
      relation = relation.or(
        user.bullets.active.where(bucket_id: monthly_bucket.id, pops_on: date)
      )
    end

    relation.chronologically
  end

  def self.inbox_count_for(user, date: Date.current)
    inbox_for(user, date: date).count
  end
end
