# frozen_string_literal: true

# Authenticated user and owner of all their bullets, buckets, projects, and settings.
class User < ApplicationRecord
  include User::Configurable

  has_many :sessions, dependent: :destroy
  has_many :login_codes, dependent: :destroy
  has_many :bullets, dependent: :destroy
  has_many :bullet_activities, dependent: :destroy
  has_many :buckets, dependent: :destroy
  has_many :monthly_buckets, through: :buckets, source: :bucketable, source_type: 'MonthlyBucket'
  has_many :projects, dependent: :destroy
  has_many :people, dependent: :destroy
  has_many :pinned_entities, dependent: :destroy
  has_many :published_entities, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
end
