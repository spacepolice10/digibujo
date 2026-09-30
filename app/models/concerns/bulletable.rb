# frozen_string_literal: true

module Bulletable
  extend ActiveSupport::Concern

  included do
    has_one :bullet, as: :bulletable, dependent: :destroy, inverse_of: :bulletable
  end

  def marker_icon       = :square
  def icon              = nil
  def colour            = nil
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
