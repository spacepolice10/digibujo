# frozen_string_literal: true

module Archivable
  extend ActiveSupport::Concern

  ARCHIVE_RETENTION_DAYS = 30

  included do
    scope :archived, -> { where(archived: true) }
    scope :active, -> { where(archived: false) }
    scope :expired_archived, lambda {
      archived
        .where.not(id: PinnedEntity.where(pinnable_type: name).select(:pinnable_id))
        .where("archives_on <= ?", ARCHIVE_RETENTION_DAYS.days.ago.to_date)
    }
  end

  def archive!
    update!(archived: true, archives_on: Date.current)
    after_archive!
  end

  def unarchive!
    update!(archived: false, archives_on: nil)
    after_unarchive!
  end

  private

  def after_archive!; end

  def after_unarchive!; end
end
