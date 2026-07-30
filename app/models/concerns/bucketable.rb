# frozen_string_literal: true

module Bucketable
  extend ActiveSupport::Concern

  included do
    has_one :bucket, as: :bucketable, inverse_of: :bucketable, touch: true, autosave: true
    has_many :bullets, through: :bucket

    delegate :name, :colour, :colour_variable, :icon, :icon_name, to: :bucket, allow_nil: true
  end
end
