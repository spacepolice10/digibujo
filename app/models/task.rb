# frozen_string_literal: true

class Task < ApplicationRecord
  include Bulletable, Completable

  def temporal?      = true
  def completable?   = true
  def completed?     = done?
  def marker_icon    = completed? ? :check : :square
  def marker_styles  = 'bullet--task-marker'
end
