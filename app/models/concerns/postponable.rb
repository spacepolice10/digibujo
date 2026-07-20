# frozen_string_literal: true

module Postponable
  extend ActiveSupport::Concern

  def postpone!(bucket:, pops_on: nil)
    raise ArgumentError, 'bucket is required' if bucket.blank?

    destination = bucket.is_a?(Bucket) ? bucket : user.buckets.active.find(bucket)
    resolved_pops_on = pops_on_for_destination(destination, pops_on)

    if bucket_id == destination.id && self.pops_on == resolved_pops_on
      record_activity!('postponed')
      return
    end

    migrate_to!(bucket: destination, pops_on: pops_on, action: 'postponed')
  end
end
