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
  def marker_icon      = :line_dashed
  def completed?       = false
  def icon             = nil
  def colour           = nil
  def excerpt_for(body) = body

  def data_attributes
    {}
  end

  module ClassMethods
    def permitted_bullet_attributes
      %i[]
    end
  end
end
