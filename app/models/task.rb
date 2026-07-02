# frozen_string_literal: true

class Task < ApplicationRecord
  include Bulletable

  def temporal? = true
  def completable?   = true
  def completed?     = self[:completed]
  def starts_date    = nil
  def ends_date      = nil
  def marker_icon    = completed? ? :check : :square
  def marker_styles  = 'bullet--task-marker'
  def self.permitted_bullet_attributes = %i[body completed]

  def complete!
    update!(completed: true, completed_at: Time.current)
    bullet.mark_migration!(action: 'completed', pops_on: bullet.pops_on)
  end

  def uncomplete!
    update!(completed: false, completed_at: nil)
    bullet.record_activity!('uncompleted')
  end
end
