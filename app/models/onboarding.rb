# frozen_string_literal: true

class Onboarding
  include ActiveModel::Validations, ActiveModel::Model

  FUTURE_BUCKET_NAME = 'Future Log'
  FUTURE_BUCKET_ICON = 'calendar'
  FUTURE_BUCKET_COLOUR = 'gold'
  LOOSE_NOTES_NAME = 'Loose Notes'

  attr_accessor :user

  validates :user, presence: true

  def complete
    return false unless valid?

    ActiveRecord::Base.transaction do
      ensure_future_bucket!
      ensure_current_monthly_bucket!
      ensure_loose_notes!
    end

    true
  rescue ActiveRecord::RecordInvalid => e
    errors.add(:base, e.message)
    false
  end

  private

  def ensure_future_bucket!
    future_bucket = FutureBucket.find_or_create_by!(user: user)
    return if future_bucket.bucket.present?

    user.buckets.create!(
      bucketable: future_bucket,
      name: FUTURE_BUCKET_NAME,
      icon: FUTURE_BUCKET_ICON,
      colour: FUTURE_BUCKET_COLOUR
    )
  end

  def ensure_current_monthly_bucket!
    future_bucket = user.future_buckets.first!
    period = MonthlyBucket.default_period
    return if future_bucket.monthly_buckets.exists?(period_from: period[:period_from])

    monthly_bucket = future_bucket.monthly_buckets.create!(
      user: user,
      **period
    )
    user.buckets.create!(
      bucketable: monthly_bucket,
      name: monthly_bucket.period_from.strftime('%B %Y'),
      icon: 'calendar'
    )
  end

  def ensure_loose_notes!
    existing = user.buckets.find_by(bucketable_type: 'Collection', name: LOOSE_NOTES_NAME.downcase)
    return if existing.present?

    collection = Collection.create!
    user.buckets.create!(bucketable: collection, name: LOOSE_NOTES_NAME)
  end
end
