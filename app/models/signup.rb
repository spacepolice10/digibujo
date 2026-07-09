# frozen_string_literal: true

class Signup
  include ActiveModel::Validations, ActiveModel::Attributes, ActiveModel::Model

  FUTURE_BUCKET_NAME = 'Future Log'
  FUTURE_BUCKET_ICON = 'calendar'
  FUTURE_BUCKET_COLOUR = 'gold'
  LOOSE_NOTES_NAME = 'Loose Notes'

  attr_accessor :email_address, :user

  validates :email_address, format: { with: URI::MailTo::EMAIL_REGEXP }, on: :identity_creation
  validates :user, presence: true, on: :completion

  def initialize(...)
    super
    self.email_address ||= user&.email_address
  end

  def create_identity
    return false unless valid?(:identity_creation)

    self.user = User.find_or_create_by(email_address: email_address)
    return false unless user.persisted?

    _record, code = LoginCode.create_for(user)
    SessionMailer.login_code(user, code).deliver_later
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  def complete
    return false unless valid?(:completion)

    ActiveRecord::Base.transaction do
      ensure_future_bucket!
      ensure_current_monthly_bucket!
      ensure_loose_notes!
      seed_sample_activities!
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

  def seed_sample_activities!
    return if user.activities.exists?

    today = Date.current
    loose_notes = user.buckets.find_by!(bucketable_type: 'Collection', name: LOOSE_NOTES_NAME.downcase)

    explore = user.bullets.create!(bulletable: Task.new(body: 'Welcome'), pops_on: today)
    explore.bulletable.update!(body: 'Explore your monthly spread')

    journal = user.bullets.create!(bulletable: Task.new(body: 'Set up your journal'), pops_on: today)
    journal.bulletable.complete!

    idea = user.bullets.create!(bulletable: Note.new(body: 'Capture ideas here before you sort them'))
    idea.collect!(bucket_id: loose_notes.id)

    daily = user.bullets.create!(bulletable: Task.new(body: 'Try the daily log'), pops_on: today - 1)
    daily.pop!(pops_on: today)

    loose_notes.update!(description: 'Quick captures before you sort them')
  end
end
