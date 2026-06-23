# frozen_string_literal: true

class Title < ApplicationRecord
  include Bulletable

  composer label: 'Title',
           hint: 'Section heading',
           icon: :heading,
           modifier: 'title',
           marker_styles: ''

  def temporal?      = false
  def completable?   = false
  def marker_icon    = :heading
  def marker_styles  = ''
end
