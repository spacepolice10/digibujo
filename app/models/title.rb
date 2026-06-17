# frozen_string_literal: true

class Title < ApplicationRecord
  include Bulletable

  validates :text, presence: true

  def temporal?      = false
  def completable?   = false
  def marker_icon    = :none
  def marker_styles  = ''
  def name           = text
  def excerpt        = text
end
