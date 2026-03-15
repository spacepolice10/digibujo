module Archivable
  extend ActiveSupport::Concern

  included do
    scope :archived, -> { where(archived: true) }
  end
end
