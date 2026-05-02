class User < ApplicationRecord
  has_many :sessions, dependent: :destroy
  has_many :login_codes, dependent: :destroy
  has_many :bullets, dependent: :destroy
  has_many :streams, dependent: :destroy
  has_many :projects, dependent: :destroy
  has_many :playlists, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
end
