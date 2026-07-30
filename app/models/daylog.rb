# frozen_string_literal: true

class Daylog < ApplicationRecord
  include Bucketable

  belongs_to :user

  validates :user_id, uniqueness: true

  def self.provision!(user)
    if (existing = user.daylog)
      return existing if existing.bucket

      user.buckets.create!(bucketable: existing, name: Onboarding::DAYLOG_NAME, icon: Onboarding::DAYLOG_ICON)
      return existing.reload
    end

    record = user.create_daylog!
    user.buckets.create!(bucketable: record, name: Onboarding::DAYLOG_NAME, icon: Onboarding::DAYLOG_ICON)
    record.reload
  end
end
