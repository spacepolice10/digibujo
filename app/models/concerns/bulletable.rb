# frozen_string_literal: true

module Bulletable
  extend ActiveSupport::Concern

  included do
    has_one :bullet, as: :bulletable, dependent: :destroy, inverse_of: :bulletable

    has_rich_text :body
  end

  def temporal?     = false
  def completable?  = false
  def starts_date   = nil
  def ends_date     = nil
  def name          = body.to_plain_text.strip.presence || 'Untitled'
  def excerpt       = body.to_plain_text.strip.presence || 'Untitled'
  def marker_icon   = :line_dashed
  def marker_styles = 'bullet--note-marker'
  def completed?    = false
  def mood_marker   = nil

  module ClassMethods
    def permitted_bullet_attributes
      %i[]
    end
  end
end
