module Colourable
  extend ActiveSupport::Concern

  COLOUR_KEYS = (1..8).map(&:to_s).freeze

  included do
    validates :colour, inclusion: { in: COLOUR_KEYS }, allow_nil: true
  end

  def colour_variable
    "var(--model-color-#{colour})" if colour.present?
  end

  def colour_bg_variable
    "var(--model-color-#{colour}-bg)" if colour.present?
  end
end
