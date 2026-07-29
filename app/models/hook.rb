# frozen_string_literal: true

# Inbound intake for external apps. Plaintext code is shown once at create.
# POSTs to /hooks/:code land bullets in the user's Pending bucket.
class Hook < ApplicationRecord
  PREFIX = 'hk_'
  CODE_BYTES = 24
  PREFIX_DISPLAY_LENGTH = 8
  INTAKE_TYPES = %w[Note Task].freeze

  belongs_to :user

  attr_accessor :code

  scope :active, -> { where(active: true) }

  validates :name, presence: true, length: { maximum: 255 }
  validates :code_digest, :code_prefix, presence: true
  validates :code_digest, uniqueness: true

  before_validation :generate_code, on: :create

  def self.digest(code)
    Digest::SHA256.hexdigest(code.to_s)
  end

  def self.authenticate(code)
    return if code.blank?

    active.find_by(code_digest: digest(code))
  end

  def create_pending_bullet!(author_name:, bulletable_type:, body:)
    type = bulletable_type.to_s.presence_in(INTAKE_TYPES)
    raise ArgumentError, 'bulletable_type is invalid' if type.blank?

    pending = Pending.provision!(user)
    user.bullets.create!(
      bucket: pending.bucket,
      pops_on: nil,
      author_name: author_name.to_s.strip.presence,
      bulletable_type: type,
      bulletable: type.constantize.new(body: body)
    )
  end

  private

  def generate_code
    return if code_digest.present?

    self.code = "#{PREFIX}#{SecureRandom.base58(CODE_BYTES)}"
    self.code_digest = self.class.digest(code)
    self.code_prefix = code.first(PREFIX_DISPLAY_LENGTH)
  end
end
