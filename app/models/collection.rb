# frozen_string_literal: true

class Collection < ApplicationRecord
  include Bucketable
  has_many :bundles, dependent: :destroy
end
