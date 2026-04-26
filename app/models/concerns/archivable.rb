module Archivable
  extend ActiveSupport::Concern

  ARCHIVE_RETENTION_DAYS = 14
  UNTRIAGED_ARCHIVE_DAYS = 7

  included do
    scope :archived,         -> { where(archived: true) }
    scope :auto_archivable,  lambda {
      where(archived: false, pinned: false).where(
        "archives_on <= :today OR (triaged_at IS NULL AND created_at <= :cutoff)",
        today: Date.today,
        cutoff: UNTRIAGED_ARCHIVE_DAYS.days.ago.end_of_day
      )
    }
    scope :expired_archived, lambda {
      archived.where(pinned: false).where("archives_on <= ?", ARCHIVE_RETENTION_DAYS.days.ago.to_date)
    }
  end

  def archive!
    update!(archived: true, archives_on: Date.today)
  end

  def unarchive!
    update!(archived: false, archives_on: nil)
  end
end
