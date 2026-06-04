module Iconable
  extend ActiveSupport::Concern

  ICON_MAPPINGS = {
    "pencil" => "pencil",
    "circle-check" => "circle-check",
    "calendar" => "calendar",
    "file" => "file",
    "book" => "book",
    "menu" => "menu",
    "pin" => "pin",
    "archive" => "archive",
    "paperclip" => "paperclip",
    "arrow-up" => "arrow-up",
  }.freeze

  included do
    validates :icon, inclusion: { in: ICON_MAPPINGS.keys }, allow_nil: true
  end

  def icon_variable
    ICON_MAPPINGS[icon]
  end
end
