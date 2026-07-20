# frozen_string_literal: true

class Collection < ApplicationRecord
  include Bucketable

  validates :description, length: { maximum: 280 }, allow_blank: true
end
