# frozen_string_literal: true

class Bullet < ApplicationRecord
  include Migratable, Collectable, Postponable, Archivable, Pinnable, Publishable, Bullet::Projectable,
          Bullet::Searchable, Bullet::ActivityRecording, ActivityTrackable

  belongs_to :user
  belongs_to :bucket
  has_many :activities, as: :subject, dependent: :destroy

  delegated_type :bulletable, types: %w[Task Note Event Voice], dependent: :destroy, optional: true, inverse_of: :bullet

  delegate :completable?, :temporal?, :name, :excerpt, :long?,
           :marker_icon, :completed?,
           :starts_date, :ends_date, :body, :data_attributes,
           :icon, :colour,
           to: :bulletable

  accepts_nested_attributes_for :bulletable

  validates :bulletable_type, inclusion: { in: ->(bullet) { bullet.class.bulletable_types } }
  validates :bulletable, presence: true
  validate :bucket_belongs_to_user
  validate :pops_on_matches_bucket_type

  before_validation :assign_daylog_home_if_missing, on: :create
  before_validation :normalize_future_pops_on

  def assign_attributes(new_attributes)
    attrs = new_attributes.to_h.with_indifferent_access
    body_value = attrs.delete(:body)
    super(attrs)
    self.body = body_value if !body_value.nil? && bulletable
  end

  def body=(value)
    bulletable.body = value if bulletable
  end

  def to_partial_path
    return '/bullets/bullet' unless bulletable

    "/#{bulletable.to_partial_path}"
  end

  def to_form_path
    bulletable.to_form_path
  end

  def migration_activity
    return unless migrated?

    activities.where(action: last_migration['action']).order(created_at: :desc).first
  end

  private


  def assign_daylog_home_if_missing
    return if bucket.present? || bucket_id.present?
    return if user.blank?

    self.bucket = Onboarding.ensure_daylog_bucket!(user)
    self.pops_on ||= Date.current
  end

  def normalize_future_pops_on
    return if pops_on.blank?
    return unless bucket&.bucketable_type == 'Future'

    self.pops_on = pops_on.to_date.beginning_of_month
  end

  def bucket_belongs_to_user
    return if bucket.blank? || user.blank?
    return if bucket.user_id == user_id

    errors.add(:bucket, 'must belong to the same user')
  end

  def pops_on_matches_bucket_type
    return if bucket.blank?

    case bucket.bucketable_type
    when 'Daylog'
      errors.add(:pops_on, 'must be present on the daylog') if pops_on.blank?
    when 'Collection'
      errors.add(:pops_on, 'must be blank') if pops_on.present?
    when 'Future'
      return if pops_on.blank?

      future = bucket.bucketable
      unless future.spread_months.include?(pops_on.beginning_of_month)
        errors.add(:pops_on, 'must be within the future spread')
      end
    end
  end
end

