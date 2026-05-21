# frozen_string_literal: true

module Bucketable
  extend ActiveSupport::Concern

  included do
    has_one :bucket, as: :bucketable, inverse_of: :bucketable, touch: true
    has_many :bullets, through: :bucket

    delegate :colour, :icon, to: :bucket, allow_nil: true
  end

  def name
    bucket&.name
  end
end
