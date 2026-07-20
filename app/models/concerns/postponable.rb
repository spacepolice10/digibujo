# frozen_string_literal: true

module Postponable
  extend ActiveSupport::Concern

  def postpone!(bucket:, pops_on: nil)
    raise ArgumentError, 'bucket is required' if bucket.blank?

    destination = bucket.is_a?(Bucket) ? bucket : user.buckets.active.find(bucket)
    resolved_pops_on = resolve_pops_on(destination, pops_on)

    return if bucket_id == destination.id && self.pops_on == resolved_pops_on

    migrate_to!(bucket: destination, pops_on: resolved_pops_on, action: 'rescheduled')
  end

  private

  def resolve_pops_on(bucket, pops_on)
    case bucket.bucketable_type
    when 'Daylog'
      pops_on.presence || Date.current
    when 'Monthlylog'
      pops_on
    when 'Future'
      return nil if pops_on.blank?

      pops_on.to_date.beginning_of_month
    when 'Collection'
      nil
    else
      pops_on
    end
  end
end
