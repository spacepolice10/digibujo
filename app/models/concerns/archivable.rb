module Archivable
  extend ActiveSupport::Concern

  included do
    scope :archived, -> { where(status: :archived) }
  end
end
