class MonthlyBucket < ApplicationRecord
  include Bucketable, Periodable
  belongs_to :user
  belongs_to :future_bucket, optional: true

  scope :covering, lambda { |date = Date.current|
    where(period_from: date.beginning_of_month)
  }

  def self.current(user)
    joins(:bucket).where(buckets: { user_id: user.id }).covering.first
  end

  def current?
    period_from == Date.current.beginning_of_month
  end

  before_validation :snap_period_from
  validate :period_unique_per_user

  private

  def snap_period_from
    self.period_from = period_from.beginning_of_month if period_from.present?
  end

  def period_unique_per_user
    return if bucket&.future_bucket_id.present?
    return unless bucket&.user_id && period_from.present?

    return unless MonthlyBucket.covering(period_from)
                               .joins(:bucket)
                               .where.not(buckets: { id: bucket.id })
                               .where(buckets: { user_id: bucket.user_id })
                               .exists?

    errors.add(:base, "A spread already exists for #{period_from.strftime('%B %Y')}")
  end
end
