# frozen_string_literal: true

# Authenticated user and owner of all their bullets, buckets, projects, and settings.
class User < ApplicationRecord
  has_one :settings, class_name: 'User::Settings', dependent: :destroy
  after_create :create_settings

  has_many :sessions, dependent: :destroy
  has_many :login_codes, dependent: :destroy
  has_many :bullets, dependent: :destroy
  has_many :activities, dependent: :destroy
  has_many :buckets, dependent: :destroy
  has_many :future_buckets, dependent: :destroy
  has_many :monthly_buckets, through: :buckets, source: :bucketable, source_type: 'MonthlyBucket'
  has_many :projects, dependent: :destroy
  has_many :people, dependent: :destroy
  has_many :pinned_entities, dependent: :destroy
  has_many :published_entities, dependent: :destroy
  has_many :search_selections, class_name: "Search::Selection", dependent: :destroy
  has_many :recurrencies, dependent: :destroy

  def settings!
    settings || create_settings!
  end

  def future_bucket
    future_buckets.order(:created_at).first
  end

  def future_bucket!
    future_bucket || begin
      created = FutureBucket.create!(user: self)
      buckets.create!(bucketable: created, name: 'Future Log')
      created
    end
  end

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
end
