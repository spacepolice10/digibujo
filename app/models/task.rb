# frozen_string_literal: true

class Task < ApplicationRecord
  include Bulletable

  composer name: 'Task',
           hint: 'Action you can complete',
           icon: :square,
           modifier: 'task',
           marker_styles: 'bullet--task-marker',
           hotkey: 'Shift+T'

  def temporal? = true
  def completable?   = true
  def completed?     = self[:completed]
  def starts_date    = nil
  def ends_date      = nil
  def marker_icon    = completed? ? :check : :square
  def marker_styles  = 'bullet--task-marker'

  class << self
    def complete_bullets!(bullets)
      transaction do
        bullets.lock.find_each do |bullet|
          bullet.bulletable.complete!
        end
      end
    end

    def uncomplete_bullets!(bullets)
      transaction do
        bullets.lock.find_each do |bullet|
          bullet.bulletable.uncomplete!
        end
      end
    end
  end

  def complete!
    update!(completed: true, completed_at: Time.current)
    bullet.mark_migration!(action: 'completed', pops_on: bullet.pops_on)
  end

  def uncomplete!
    update!(completed: false, completed_at: nil)
    bullet.record_activity!('uncompleted')
  end
end
