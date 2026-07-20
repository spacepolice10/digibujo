# frozen_string_literal: true

class PinnedEntity < ApplicationRecord
  belongs_to :user
  belongs_to :pinnable, polymorphic: true

  validates :pinnable_id, uniqueness: { scope: %i[user_id pinnable_type] }

  after_create :record_pinned_activity!
  before_destroy :record_unpinned_activity!, unless: :destroyed_by_association

  private

  def record_pinned_activity!
    return unless pinnable.respond_to?(:record_activity!)

    pinnable.record_activity!('pinned', metadata: pin_activity_metadata)
  end

  def record_unpinned_activity!
    return unless pinnable.respond_to?(:record_activity!)

    pinnable.record_activity!('unpinned', metadata: pin_activity_metadata)
  end

  def pin_activity_metadata
    return {} unless pinnable.is_a?(Bucket)

    { 'bucketable_type' => pinnable.bucketable_type }
  end
end
