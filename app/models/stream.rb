class Stream < ApplicationRecord
  include Colourable
  include Iconable

  belongs_to :user

  store_accessor :fields, :bulletable_type, :sorted_by, :date_from, :date_to, :projects, :icon, :colour

  validates :name, presence: true, uniqueness: { scope: :user_id }

  scope :ordered, -> { order(created_at: :asc) }

  class << self
    def fields_keys
      %w[bulletable_type sorted_by date_from date_to projects icon colour]
    end
  end

  def bullets
    scope = user.bullets.includes(:project)
    scope = filter_by_bulletable_type(scope)
    scope = filter_by_date_from(scope)
    scope = scope.where("scheduled_on <= ?", date_to) if date_to.present?
    scope = filter_by_projects(scope)
    scope = scope.order(created_at: sorted_by == "oldest" ? :asc : :desc)
    scope
  end

  def empty?
    fields.except("icon", "colour").compact_blank.blank?
  end

  private

  def filter_by_bulletable_type(scope)
    return scope if bulletable_type.blank?

    types = bulletable_type.split(",").map(&:strip).reject(&:blank?)
    return scope if types.empty?

    scope.where(bulletable_type: types)
  end

  def filter_by_date_from(scope)
    return scope if date_from.blank?

    resolved = date_from == "today" ? Date.current : date_from
    scope.where("scheduled_on >= ?", resolved)
  end

  def filter_by_projects(scope)
    return scope if projects.blank?

    names = projects.split(",").map(&:strip).reject(&:blank?)
    return scope if names.empty?

    scope.joins(:project).where(projects: { name: names }).distinct
  end
end
