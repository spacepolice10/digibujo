# frozen_string_literal: true

module Bucketable
  extend ActiveSupport::Concern

  included do
    has_one :bucket, as: :bucketable, inverse_of: :bucketable, touch: true, autosave: true
    has_many :bullets, through: :bucket

    delegate :colour, :icon, :icon_path, to: :bucket, allow_nil: true
  end

  def name
    bucket&.name
  end

  def icon_mask
    bucket&.icon_mask
  end

  def colour_variable
    bucket&.colour_variable
  end

  class_methods do
    def sanitized_name_query(query)
      ActiveRecord::Base.sanitize_sql_like(query.to_s.strip.downcase).presence
    end

    def matching_bucket_name(query)
      sanitized = sanitized_name_query(query)
      sanitized ? where('LOWER(buckets.name) LIKE ?', "#{sanitized}%") : all
    end
  end
end
