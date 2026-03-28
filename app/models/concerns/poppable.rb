module Poppable
  extend ActiveSupport::Concern

  included do
    scope :popped,   -> { where.not(pops_on: nil).where("pops_on <= ?", Date.today) }
    scope :unpopped, -> { where(pops_on: nil) }
  end

  def popped?
    pops_on.present? && pops_on <= Date.today
  end
end
