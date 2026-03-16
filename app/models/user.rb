class User < ApplicationRecord
  has_many :sessions, dependent: :destroy
  has_many :login_codes, dependent: :destroy
  has_many :cards, dependent: :destroy
  has_many :streams, dependent: :destroy
  has_many :tags, dependent: :destroy

  after_create :create_default_streams

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  private

  def create_default_streams
    Stream::DEFAULTS.each do |attrs|
      streams.create!(name: attrs[:name], default: true, position: attrs[:position], fields: attrs[:fields])
    end
  end
end
