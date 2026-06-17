# frozen_string_literal: true

class Title < ApplicationRecord
  include Bulletable

  def temporal?      = false
  def completable?   = false
  def marker_icon    = :none
  def marker_styles  = ''
end
