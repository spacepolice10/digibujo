module Publishable
  extend ActiveSupport::Concern

  included do
    scope :published, -> { where.not(public_code: nil) }
  end

  def published?
    public_code.present?
  end

  def publish!
    update!(public_code: SecureRandom.urlsafe_base64(16))
  end

  def unpublish!
    update!(public_code: nil)
  end
end
