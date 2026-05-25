module Pinnable
  extend ActiveSupport::Concern

  MAXIMUM_PINNED_BULLETS = 10

  included do
    scope :pinned, -> { where(pinned: true) }
    validate :less_than_maximum_pinned_bullets, if: :pinned?
  end

  private

  def less_than_maximum_pinned_bullets
    return unless pinned_changed?(to: true)
    if Current.user.bullets.pinned.where.not(id: id).count >= MAXIMUM_PINNED_BULLETS
      errors.add(:base, "Cannot pin more than #{MAXIMUM_PINNED_BULLETS} bullets")
    end
  end
end
