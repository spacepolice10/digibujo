module Archivable
  extend ActiveSupport::Concern

  ARCHIVE_RETENTION_DAYS = 14

  included do
    scope :archived,         -> { where(archived: true) }
    scope :auto_archivable,  -> { where(archived: false).where("archives_on <= ?", Date.today) }
    scope :expired_archived, -> { archived.where("archives_on <= ?", ARCHIVE_RETENTION_DAYS.days.ago.to_date) }
  end

  def archive!
    update!(archived: true, archives_on: Date.today)
  end

  def unarchive!
    update!(archived: false, archives_on: nil)
  end
end
