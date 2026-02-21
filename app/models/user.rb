class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :cards, dependent: :destroy
  has_many :filters, dependent: :destroy
  has_many :tags, dependent: :destroy

  after_create :create_default_filters

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  private

  def create_default_filters
    filters.create!(name: "Tasks", fields: { "cardable_type" => "Task" })
    filters.create!(name: "Notes", fields: { "cardable_type" => "Note" })
  end
end
