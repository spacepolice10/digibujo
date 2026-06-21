# frozen_string_literal: true

class RecurrencyCompletion < ApplicationRecord
  belongs_to :recurrency

  validates :date, presence: true, uniqueness: { scope: :recurrency_id }
  validates :completed_at, presence: true
end
