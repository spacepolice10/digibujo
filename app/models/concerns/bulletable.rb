# frozen_string_literal: true

module Bulletable
  extend ActiveSupport::Concern

  included do
    has_one :bullet, as: :bulletable, dependent: :destroy, inverse_of: :bulletable
  end

  def temporal?        = false
  def completable?     = false
  def starts_date      = nil
  def ends_date        = nil
  def name             = 'Untitled'
  def excerpt          = 'Untitled'
  def long?            = false
  def marker_icon      = :line_dashed
  def completed?       = false
  def icon             = nil
  def colour           = nil

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
