# frozen_string_literal: true

module Bulletable
  extend ActiveSupport::Concern

  included do
    has_one :bullet, as: :bulletable, dependent: :destroy
  end

  def temporal?      = false
  def completable?   = false
  def name           = bullet.body.to_plain_text.strip.presence || 'Untitled'
  def excerpt        = name
  def marker_icon    = :line_dashed
  def marker_styles  = 'bullet--note-marker'
  def completed?     = false
  def mood_marker    = nil
  def meta_labels    = []

  module ClassMethods
    def composer(label: nil, hint: nil, icon: nil, modifier: nil, marker_styles: nil, form_partial: nil)
      config = composer_config
      config[:label] = label if label
      config[:hint] = hint if hint
      config[:icon] = icon if icon
      config[:modifier] = modifier if modifier
      config[:marker_styles] = marker_styles if marker_styles
      config[:form_partial] = form_partial if form_partial
      config
    end

    def composer_config
      @composer_config ||= {
        label: to_s,
        hint: nil,
        icon: :line_dashed,
        modifier: to_s.downcase,
        marker_styles: 'bullet--note-marker',
        form_partial: nil
      }
    end

    def bulletable_form_fields? = composer_config[:form_partial].present?
  end
end
