class SweepLoginCodesJob < ApplicationJob
  def perform
    LoginCode.sweep
  end
end
