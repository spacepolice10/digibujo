# frozen_string_literal: true

class SweepActivityLogsJob < ApplicationJob
  def perform
    Activity.sweep
  end
end
