module Iconable
  extend ActiveSupport::Concern

  ICON_KEYS = %w[
    pencil circle-check calendar file book menu
    pin archive paperclip arrow-up
  ].freeze

  included do
    validates :icon, inclusion: { in: ICON_KEYS }, allow_nil: true
  end
end
