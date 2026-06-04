module Colourable
  extend ActiveSupport::Concern

  COLOUR_MAPPINGS = {
    "violet" => "var(--model-color-1)",
    "cobalt"   => "var(--model-color-2)",
    "teal" => "var(--model-color-3)",
    "emerald" => "var(--model-color-4)",
    "gold" => "var(--model-color-5)",
    "vermillion" => "var(--model-color-6)",
    "magenta" => "var(--model-color-7)",
    "inks" => "var(--model-color-8)",
  }.freeze

  included do
    validates :colour, inclusion: { in: COLOUR_MAPPINGS.keys }, allow_nil: true
  end

  def colour_variable
    COLOUR_MAPPINGS[colour]
  end

  def colour_bg_variable
    colour_variable&.sub(/\)\z/, "-bg)")
  end

  def self.colour_bg_variable_for(name)
    COLOUR_MAPPINGS[name]&.sub(/\)\z/, "-bg)")
  end
end
