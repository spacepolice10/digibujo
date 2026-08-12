# frozen_string_literal: true

# Named Active Storage transformations used for on-screen display.
# Prefer these over serving the original blob.
module ImageVariant
  TRANSFORMATIONS = {
    thumb: { resize_to_limit: [128, 128] },
    preview: { resize_to_limit: [800, 800] },
    display: { resize_to_limit: [1600, 1600] },
    header: { resize_to_fill: [1200, 200] },
    band: { resize_to_fill: [720, 180] }
  }.freeze

  def self.[](name)
    TRANSFORMATIONS.fetch(name)
  end
end
