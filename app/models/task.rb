# frozen_string_literal: true

class Task < ApplicationRecord
  include Bulletable, Completable

  composer label: 'Task',
           hint: 'Action you can complete',
           icon: :square,
           modifier: 'task',
           marker_styles: 'bullet--task-marker'

  def temporal?      = true
  def completable?   = true
  def completed?     = done?
  def marker_icon    = completed? ? :check : :square
  def marker_styles  = 'bullet--task-marker'
end
