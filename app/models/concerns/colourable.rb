module Colourable
  extend ActiveSupport::Concern

  COLOUR_KEYS = (1..8).map(&:to_s).freeze

  included do
    validates :colour, inclusion: { in: COLOUR_KEYS }, allow_nil: true
  end
end
