# frozen_string_literal: true

class Tracker::Status < ApplicationRecord
  self.table_name = 'tracker_statuses'

  belongs_to :tracker
  belongs_to :calendar_date

  delegate :date, to: :calendar_date

  validates :calendar_date_id, uniqueness: { scope: :tracker_id }
  validates :completed_at, presence: true
end
