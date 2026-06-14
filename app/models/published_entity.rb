# frozen_string_literal: true

class PublishedEntity < ApplicationRecord
  belongs_to :user
  belongs_to :publishable, polymorphic: true

  validates :code, uniqueness: true

  before_create :set_defaults

  private

  def set_defaults
    self.code ||= SecureRandom.urlsafe_base64(16)
    self.published_at ||= Time.current
  end
end
