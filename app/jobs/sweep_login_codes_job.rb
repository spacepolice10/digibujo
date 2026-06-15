# frozen_string_literal: true

class SweepLoginCodesJob < ApplicationJob
  def perform
    LoginCode.sweep
  end
end
