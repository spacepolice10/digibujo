class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :cards, dependent: :destroy
  has_many :streams, dependent: :destroy
  has_many :tags, dependent: :destroy

  after_create :create_default_streams

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  private

  def create_default_streams
    streams.create!(name: "Tasks", fields: { "cardable_type" => "Task" })
    streams.create!(name: "Notes", fields: { "cardable_type" => "Note" })
  end
end
