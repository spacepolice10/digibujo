module Stashable
  extend ActiveSupport::Concern

  STASH_LIMIT = 10

  included do
    scope :stashed, -> { where(status: :stashed) }
    validate :stash_limit_not_exceeded, if: :stashed?
  end

  private

  def stash_limit_not_exceeded
    return unless status_changed?(to: "stashed")
    if user.cards.stashed.where.not(id: id).count >= STASH_LIMIT
      errors.add(:base, "Cannot stash more than #{STASH_LIMIT} cards")
    end
  end
end
