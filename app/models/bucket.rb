# frozen_string_literal: true

class Bucket < ApplicationRecord
  include Archivable, Colourable, Iconable, Pinnable, Bucket::Searchable, ActivityTrackable

  belongs_to :user
  has_many :bullets, dependent: :destroy

  delegated_type :bucketable, types: %w[Collection Future Monthlylog Daylog], dependent: :destroy

  validates :name, presence: true

  normalizes :name, with: ->(name) { name.strip.downcase }

  scope :matching_name, lambda { |query|
    sanitized = sanitized_name_query(query)
    sanitized ? where('LOWER(name) LIKE ?', "#{sanitized}%") : all
  }

  def self.sanitized_name_query(query)
    sanitize_sql_like(query.to_s.strip.downcase).presence
  end
end
