# frozen_string_literal: true

module Bucketable
  extend ActiveSupport::Concern

  included do
    has_one :bucket, as: :bucketable, inverse_of: :bucketable, touch: true
    has_many :bullets, through: :bucket

    delegate :colour, :icon, to: :bucket, allow_nil: true
    delegate :period_from, :period_to, :period?, :period_days, :covers?, to: :bucket, allow_nil: true
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
end
