# frozen_string_literal: true

# Provisions the initial workspace and optional guided sample content for a new user.
class Onboarding
  include ActiveModel::Validations, ActiveModel::Model

  FUTURE_NAME = 'Future Log'
  FUTURE_ICON = 'calendar'
  FUTURE_COLOUR = 'gold'
  DAYLOG_NAME = 'Daylog'
  DAYLOG_ICON = 'calendar'
  PENDING_NAME = 'Pending'
  PENDING_ICON = 'memo'

  SAMPLE_DATA = YAML.safe_load_file(Rails.root.join('config/onboarding_sample_data.yml'), aliases: false)
                    .deep_symbolize_keys.freeze
  DAYLOG_BULLETS = SAMPLE_DATA.fetch(:daylog).freeze
  DAYLOG_YESTERDAY_BULLETS = SAMPLE_DATA.fetch(:daylog_yesterday).freeze
  MONTHLYLOG_BULLETS = SAMPLE_DATA.fetch(:monthlylog).freeze
  FUTURE_BULLETS = SAMPLE_DATA.fetch(:future).freeze
  COLLECTIONS = SAMPLE_DATA.fetch(:collections).freeze

  attr_accessor :user, :data_seed

  validates :user, presence: true

  def complete
    return false unless valid?

    ActiveRecord::Base.transaction { provision! }

    true
  rescue ActiveRecord::RecordInvalid => e
    errors.add(:base, e.message)
    false
  end

  def data_seed?
    %w[true 1].include?(data_seed.to_s)
  end

  private

  def provision!
    ensure_daylog!
    ensure_monthlylog!
    ensure_pending!
    user.update!(onboarded: true)
    seed_sample_data! if data_seed?
  end

  def ensure_daylog!
    Daylog.provision!(user)
  end

  def ensure_monthlylog!
    Monthlylog.provision!(user)
  end

  def ensure_pending!
    Pending.provision!(user)
  end

  def seed_sample_data!
    return if user.bullets.any?

    create_bullets!(ensure_daylog!.bucket, DAYLOG_BULLETS, default_pops_on: Date.current)
    create_bullets!(ensure_daylog!.bucket, DAYLOG_YESTERDAY_BULLETS, default_pops_on: Date.yesterday)
    seed_monthlylog!
    seed_collections!
    create_bullets!(ensure_future!.bucket, FUTURE_BULLETS)
  end

  def seed_monthlylog!
    monthlylog = ensure_monthlylog!
    bullets = MONTHLYLOG_BULLETS.map do |attributes|
      next attributes.except(:onboarding_day).merge(pops_on: user.created_at.to_date) if attributes[:onboarding_day]

      offset = attributes[:date_offset]
      next attributes.except(:date_offset) unless offset

      attributes.except(:date_offset).merge(pops_on: monthly_date(monthlylog, offset))
    end
    create_bullets!(monthlylog.bucket, bullets)
  end

  def seed_collections!
    COLLECTIONS.each do |attributes|
      collection = Collection.create!(description: attributes[:description])
      bucket = user.buckets.create!(
        bucketable: collection,
        name: attributes[:name],
        icon: attributes[:icon],
        colour: attributes[:colour]
      )
      create_bullets!(bucket, attributes[:bullets])
    end
  end

  def ensure_future!
    future = user.futures.find_or_create_by!(period_from: Date.current.beginning_of_month)
    return future if future.bucket

    user.buckets.create!(
      bucketable: future,
      name: FUTURE_NAME,
      icon: FUTURE_ICON,
      colour: FUTURE_COLOUR
    )
    future.reload
  end

  def create_bullets!(bucket, definitions, default_pops_on: nil)
    definitions.each do |definition|
      attributes = definition.except(:type)
      attributes[:pops_on] = default_pops_on unless attributes.key?(:pops_on)
      user.bullets.create!(
        bucket: bucket,
        bulletable: definition.fetch(:type).constantize.new,
        **attributes
      )
    end
  end

  def monthly_date(monthlylog, offset)
    [monthlylog.period_from + offset.days, monthlylog.period_to].min
  end
end
