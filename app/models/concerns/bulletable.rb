module Bulletable
  extend ActiveSupport::Concern

  included do
    has_one :bullet, as: :bulletable, dependent: :destroy
  end

  def temporal?      = false
  def completable?   = false
  def name           = bullet.content.to_plain_text.strip.presence || "Untitled"
  def excerpt        = name
  def body           = bullet.content
  def marker_icon    = :line_dashed
  def marker_styles  = "bullet--note-marker"
  def completed?     = false
  def mood_marker    = nil
  def meta_labels    = []

  module ClassMethods
    def bulletable_form_fields? = false
  end
end
