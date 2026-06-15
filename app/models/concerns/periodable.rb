# frozen_string_literal: true

module Periodable
  extend ActiveSupport::Concern

  included do
    validate :period_ranges_correct
  end

  class_methods do
    def default_period
      {
        period_from: Date.current.beginning_of_month,
        period_to: Date.current.end_of_month
      }
    end
  end

  def period?
    period_from.present? && period_to.present?
  end

  def period_days
    period? ? (period_from..period_to) : nil
  end

  def covers?(date)
    period? && period_days.cover?(date)
  end

  private

  def period_ranges_correct
    return if period_from.blank? && period_to.blank?

    if period_from.present? ^ period_to.present?
      errors.add(:base, 'From and To must both be set or both be blank')
      return
    end

    return unless period_from.present? && period_to.present? && period_to < period_from

    errors.add(:period_to, 'must be on or after From')
  end
end
