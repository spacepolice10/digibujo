# frozen_string_literal: true

class Daylog
  # Read model for all active bullets that can migrate into a given day.
  class Triage
    attr_reader :user, :date

    def initialize(user, date: Date.current)
      @user = user
      @date = date
    end

    def pending_bullets
      @pending_bullets ||= bullets_from(user.pending&.bucket)
    end

    def monthlylog_bullets
      @monthlylog_bullets ||= bullets_from(user.monthlylogs.covering(date).take&.bucket, pops_on: date)
    end

    def yesterday_bullets
      @yesterday_bullets ||= bullets_from(user.daylog&.bucket, pops_on: date - 1.day, unmigrated: true)
    end

    def bullets
      @bullets ||= pending_bullets + monthlylog_bullets + yesterday_bullets
    end

    def number
      bullets.size
    end

    def number_by_type(type)
      bullets.count { |bullet| bullet.bulletable_type == type.to_s.classify }
    end

    private

    def bullets_from(bucket, pops_on: :any, unmigrated: false)
      return [] unless bucket

      scope = bucket.bullets.active.includes(:bulletable).chronologically
      scope = scope.where(pops_on: pops_on) unless pops_on == :any
      scope = scope.where(migrated_at: nil) if unmigrated
      scope.to_a
    end
  end
end
