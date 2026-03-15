module Pinnable
  extend ActiveSupport::Concern

  PIN_LIMIT = 10

  included do
    scope :pinned, -> { where(pinned: true) }
    validate :pin_limit_not_exceeded, if: :pinned?
  end

  private

  def pin_limit_not_exceeded
    return unless pinned_changed?(to: true)
    if user.cards.pinned.where.not(id: id).count >= PIN_LIMIT
      errors.add(:base, "Cannot pin more than #{PIN_LIMIT} cards")
    end
  end
end
