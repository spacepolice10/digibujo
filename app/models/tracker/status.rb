# frozen_string_literal: true

class Tracker::Status < ApplicationRecord
  self.table_name = 'tracker_statuses'

  belongs_to :tracker
  belongs_to :calendar_date, optional: true

  validates :date, presence: true, uniqueness: { scope: :tracker_id }
  validates :completed_at, presence: true
end
