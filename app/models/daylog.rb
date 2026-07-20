# frozen_string_literal: true

class Daylog < ApplicationRecord
  include Bucketable

  belongs_to :user

  validates :user_id, uniqueness: true
end
