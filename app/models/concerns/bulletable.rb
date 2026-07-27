# frozen_string_literal: true

module Bulletable
  extend ActiveSupport::Concern

  EXCERPT_LIMIT = 400

  included do
    has_one :bullet, as: :bulletable, dependent: :destroy, inverse_of: :bulletable
    has_rich_text :body
  end

  def temporal?        = false
  def completable?     = false
  def starts_date      = nil
  def ends_date        = nil
  def body_as_text     = body.to_plain_text.to_s
  def name             = body_as_text.lines.first&.strip.presence || 'Untitled'
  def long?            = body_as_text.length > EXCERPT_LIMIT
  def marker_icon      = :line_dashed
  def completed?       = false
  def icon             = nil
  def colour           = nil

  # Short bodies render as rich text; long ones collapse to a plain-text tail
  # because the first line is already shown as a heading.
  def excerpt
    return 'Untitled' if body_as_text.strip.empty?
    return body unless long?

    body_as_text.lines.drop(1).join.truncate(EXCERPT_LIMIT)
  end

  def to_partial_path
    "#{self.class.model_name.route_key}/#{self.class.model_name.element}"
  end

  def to_form_path
    "#{self.class.model_name.route_key}/form"
  end

  def data_attributes
    {}
  end

  module ClassMethods
    def permitted_bullet_attributes
      %i[]
    end
  end
end
