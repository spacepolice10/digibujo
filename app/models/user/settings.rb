# frozen_string_literal: true

# Per-user settings. One row per user, created automatically.
#
class User::Settings < ApplicationRecord
  SECTION_COLUMNS = {
    'logs' => :logs_expanded,
    'projects' => :projects_expanded,
    'collections' => :collections_expanded,
    'archived' => :archived_expanded,
    'published' => :published_expanded
  }.freeze
  SECTIONS = SECTION_COLUMNS.keys.freeze

  APPEARANCES = %w[default warm cool nature cheese].freeze

  belongs_to :user

  validates :appearance, inclusion: { in: APPEARANCES }
end
