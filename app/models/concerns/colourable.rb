module Colourable
  extend ActiveSupport::Concern

  COLOUR_KEYS = (1..8).map(&:to_s).freeze

  included do
    validates :colour, inclusion: { in: COLOUR_KEYS }, allow_nil: true
  end

  def colour_var
    "var(--model-color-#{colour})" if colour.present?
  end

  def colour_bg_var
    "var(--model-color-#{colour}-bg)" if colour.present?
  end

  def colour_style
    return "" unless colour.present?
    "color: var(--model-color-#{colour}); background: var(--model-color-#{colour}-bg);"
  end
end
