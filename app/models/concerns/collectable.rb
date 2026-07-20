# frozen_string_literal: true

module Collectable
  extend ActiveSupport::Concern

  def collect!(bucket_id:)
    destination = user.buckets.active.find(bucket_id)
    migrate_to!(bucket: destination, pops_on: nil, action: 'collected')
  end
end
