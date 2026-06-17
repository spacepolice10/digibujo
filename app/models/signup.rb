# frozen_string_literal: true

class Signup
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations

  FUTURE_LOG_NAME = 'Future Log'
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
      ensure_future_log!
      ensure_loose_notes!
    end

    true
  rescue ActiveRecord::RecordInvalid => error
    errors.add(:base, error.message)
    false
  end

  private

  def ensure_future_log!
    future_bucket = FutureBucket.find_or_create_by!(user: user)
    return if future_bucket.bucket.present?

    user.buckets.create!(bucketable: future_bucket, name: FUTURE_LOG_NAME)
  end

  def ensure_loose_notes!
    existing = user.buckets.find_by(bucketable_type: 'Collection', name: LOOSE_NOTES_NAME.downcase)
    return if existing.present?

    collection = Collection.create!
    user.buckets.create!(bucketable: collection, name: LOOSE_NOTES_NAME)
  end
end
