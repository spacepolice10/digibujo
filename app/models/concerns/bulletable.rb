# frozen_string_literal: true

module Bulletable
  extend ActiveSupport::Concern

  included do
    has_one :bullet, as: :bulletable, dependent: :destroy
  end

  def temporal?                = false
  def completable?             = false
  def name          = bullet.body.to_plain_text.strip.presence || 'Untitled'
  def body          = bullet.body
  def marker_icon   = :line_dashed
  def marker_styles = 'bullet--note-marker'
  def completed?    = false
  def mood_marker   = nil

  module ClassMethods
    def permitted_bullet_attributes
      []
    end
  end
end
