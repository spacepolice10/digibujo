module Archivable
  extend ActiveSupport::Concern

  ARCHIVE_RETENTION_DAYS = 30
  UNTRIAGED_ARCHIVE_DAYS = 30

  included do
    scope :archived,         -> { where(archived: true) }
    scope :expired_archived, lambda {
      archived.where(pinned: false).where("archives_on <= ?", ARCHIVE_RETENTION_DAYS.days.ago.to_date)
    }
  end

  def archive!
    update!(archived: true, archives_on: Date.current)
    BulletActivityRecorder.record_archived!(bullet: self)
  end

  def unarchive!
    update!(archived: false, archives_on: nil)
  end
end
