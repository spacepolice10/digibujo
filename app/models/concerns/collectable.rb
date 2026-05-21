# frozen_string_literal: true

module Collectable
  extend ActiveSupport::Concern

  def collect!(bucket_id:)
    bucket = user.buckets.find(bucket_id)
    update!(
      bucket: bucket,
      triaged_at: triaged_at || Time.current
    )
    BulletActivityRecorder.record_collected!(bullet: self)
  end

  def uncollect!
    update!(bucket_id: nil)
  end
end
