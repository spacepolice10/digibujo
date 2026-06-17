# frozen_string_literal: true

class FutureBucket < ApplicationRecord
  include Bucketable
  belongs_to :user
  has_many :monthly_buckets, dependent: :destroy

  validates :user_id, uniqueness: true
end
