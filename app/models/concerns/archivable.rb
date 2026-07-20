# frozen_string_literal: true

module Archivable
  extend ActiveSupport::Concern

  RETENTION_DAYS = 30

  included do
    has_one :archive, as: :archivable, dependent: :destroy

    scope :archived, -> { joins(:archive) }
    scope :active, -> { where.missing(:archive) }
    scope :expired_archived, lambda {
      joins(:archive)
        .where.not(id: PinnedEntity.where(pinnable_type: model.name).select(:pinnable_id))
        .where(archives: { created_at: ...RETENTION_DAYS.days.ago })
    }
  end

  def archived?
    archive.present?
  end

  def archives_on
    archive&.created_at&.to_date
  end

  def archive!
    create_archive!(user: user)
  end

  def unarchive!
    archive&.destroy!
  end
end
