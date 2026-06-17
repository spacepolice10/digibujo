# frozen_string_literal: true

# Per-user settings. One row per user, created automatically.
#
# rubocop:disable Style/ClassAndModuleChildren
class User::Settings < ApplicationRecord
  SECTION_COLUMNS = {
    'logs'        => :logs_expanded,
    'projects'    => :projects_expanded,
    'collections' => :collections_expanded,
    'spreads'     => :spreads_expanded,
    'people'      => :people_expanded
  }.freeze
  SECTIONS = SECTION_COLUMNS.keys.freeze

  belongs_to :user
end
# rubocop:enable Style/ClassAndModuleChildren
