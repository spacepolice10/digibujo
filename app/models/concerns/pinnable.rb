module Pinnable
  extend ActiveSupport::Concern

  included do
    scope :pinned, -> { where(pinned: true) }
  end

  def pin!
    update(pinned: true)
  end

  def unpin!
    update!(pinned: false)
  end

  def pinned?
    pinned.present?
  end
end
