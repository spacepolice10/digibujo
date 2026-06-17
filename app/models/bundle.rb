# frozen_string_literal: true

class Bundle < ApplicationRecord
  include Bucketable
  belongs_to :user
  belongs_to :collection

  validates :collection, presence: true
end
