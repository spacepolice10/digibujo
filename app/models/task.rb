# frozen_string_literal: true

class Task < ApplicationRecord
  include Bulletable

  def temporal? = true
  def completable?   = true
  def completed?     = self[:completed]
  def starts_date    = nil
  def ends_date      = nil
  def marker_icon    = completed? ? :check : :square
  def icon           = completed? ? :check : :square
  def placeholder    = 'What need to be done?'
  def data_attributes = { task_completed: completed? }

  def self.permitted_bullet_attributes = %i[body completed]

  def complete!
    update!(completed: true, completed_at: Time.current)
    bullet.mark_migration!(action: 'completed', pops_on: bullet.pops_on)
    bullet.forget_search_selections!
  end

  def uncomplete!
    update!(completed: false, completed_at: nil)
    bullet.record_activity!('uncompleted')
  end
end
