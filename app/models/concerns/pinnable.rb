module Pinnable
  extend ActiveSupport::Concern

  included do
    scope :timeline_order, -> { active.order(pinned: :desc, created_at: :desc) }
    validate :pinned_only_when_active
  end

  private

  def pinned_only_when_active
    errors.add(:pinned, "can only be set for active cards") if pinned? && !active?
  end
end
