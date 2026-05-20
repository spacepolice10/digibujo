# frozen_string_literal: true

module Collectable
  extend ActiveSupport::Concern

  def collect!(bucket_id: nil)
    attrs = { triaged_at: triaged_at || Time.current }
    transaction do
      if bucket_id.present?
        bucket = user.buckets.find(bucket_id)
        update!(attrs.merge(bucket: bucket))
      else
        update!(attrs)
        purge_project_bucket_links!
      end
    end
  end

  private

  def purge_project_bucket_links!
    return unless bucket&.bucketable_type == 'Project'

    update!(bucket_id: nil)
  end
end
