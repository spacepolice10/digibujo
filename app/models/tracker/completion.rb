# frozen_string_literal: true

class Tracker::Completion < ApplicationRecord
  belongs_to :tracker

  validates :date, presence: true, uniqueness: { scope: :tracker_id }
  validates :completed_at, presence: true
end
