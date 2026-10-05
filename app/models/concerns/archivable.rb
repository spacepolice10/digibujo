# frozen_string_literal: true

module Archivable
  extend ActiveSupport::Concern

  RETENTION_DAYS = 30

  included do
    has_one :archive, as: :archivable, dependent: :destroy

    scope :archived, -> { joins(:archive) }
    scope :active, -> { where.missing(:archive) }
    scope :expired_archived, lambda {
      joins(:archive).where(archives: { created_at: ...RETENTION_DAYS.days.ago })
    }
  end

  def archived?
    archive.present?
  end

  def archive!
    return if archived?

    create_archive!(user: user)
    forget_search_selections! if respond_to?(:forget_search_selections!)
  end

  def unarchive!
    return unless archived?

    archive.destroy!
  end

  def archives_on
    archive&.created_at&.to_date
  end
end
