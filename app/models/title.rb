# frozen_string_literal: true

class Title < ApplicationRecord
  include Bulletable

  def temporal?      = false
  def completable?   = false
  def marker_icon    = :heading
  def marker_styles  = ''
end
