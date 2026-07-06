# frozen_string_literal: true

module Collectable
  extend ActiveSupport::Concern

  def collect!(bucket_id:)
    bucket = user.buckets.active.find(bucket_id)

    update!(bucket: bucket, pops_on: nil)
    mark_migration!(
      action: 'collected',
      bucket_id: bucket.id,
      bucket_name: bucket.name,
      bucketable_type: bucket.bucketable_type
    )
  end

  def uncollect!
    update!(bucket_id: nil)
  end
end
