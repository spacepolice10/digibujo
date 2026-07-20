# frozen_string_literal: true

class Task < ApplicationRecord
  include Bulletable
  include PlainBodyBulletable

  def temporal? = true
  def completable?   = true
  def completed?     = self[:completed]
  def marker_icon    = completed? ? :check : :square
  def icon           = completed? ? :check : :square
  def colour         = 'cobalt'
  def data_attributes = { task_completed: completed? }

  def self.permitted_bullet_attributes = %i[id body completed]

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
