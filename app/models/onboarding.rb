# frozen_string_literal: true

class Onboarding
  include ActiveModel::Validations, ActiveModel::Model

  FUTURE_NAME = 'Future Log'
  FUTURE_ICON = 'calendar'
  FUTURE_COLOUR = 'gold'
  LOOSE_NOTES_NAME = 'Loose Notes'
  DAYLOG_NAME = 'Daylog'
  DAYLOG_ICON = 'calendar'
  PENDING_NAME = 'Pending'
  PENDING_ICON = 'memo'
  COLLECTION_NAME = 'Reading list'

  attr_accessor :user, :data_seed

  validates :user, presence: true

  def complete
    return false unless valid?

    ActiveRecord::Base.transaction do
      ensure_daylog!
      ensure_monthlylog!
      ensure_pending!
      user.update!(onboarded: true)
      seed_sample_data! if data_seed?
    end

    true
  rescue ActiveRecord::RecordInvalid => e
    errors.add(:base, e.message)
    false
  end

  def data_seed?
    %w[true 1].include?(data_seed.to_s)
  end

  private

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

    seed_daylog!
    seed_monthlylog!
    seed_loose_notes!
    seed_collection!
    seed_future!
  end

  def seed_daylog!
    bucket = ensure_daylog!.bucket
    [
      Task.new(body: 'Buy groceries and plan the week'),
      Event.new(body: 'Standup with the team'),
      Note.new(body: 'Ideas for the weekend hike')
    ].each do |bulletable|
      user.bullets.create!(bucket: bucket, bulletable: bulletable, pops_on: Date.current)
    end
  end

  def seed_monthlylog!
    monthlylog = ensure_monthlylog!
    month = monthlylog.period_from
    dates = [Date.current + 1.day, Date.current + 3.days]
             .map { |date| [date, month.end_of_month].min }
             .uniq
    bullets = [
      { bulletable: Event.new(body: 'Team offsite'), pops_on: dates[0] },
      { bulletable: Task.new(body: 'Prepare monthly review'), pops_on: dates[1] },
      { bulletable: Note.new(body: 'Monthly themes to explore'), pops_on: nil }
    ]
    bullets.each do |attrs|
      user.bullets.create!(bucket: monthlylog.bucket, **attrs)
    end
  end

  def seed_loose_notes!
    bucket = ensure_loose_notes!
    [
      Note.new(body: 'Random thought worth keeping'),
      Note.new(body: 'A link or idea to revisit')
    ].each do |bulletable|
      user.bullets.create!(bucket: bucket, bulletable: bulletable, pops_on: nil)
    end
  end

  def seed_collection!
    collection = Collection.create!
    bucket = user.buckets.create!(bucketable: collection, name: COLLECTION_NAME)
    [
      Task.new(body: 'Atomic Habits'),
      Task.new(body: 'The Bullet Journal Method'),
      Note.new(body: 'Book recommendations from Alex')
    ].each do |bulletable|
      user.bullets.create!(bucket: bucket, bulletable: bulletable, pops_on: nil)
    end
  end

  def seed_future!
    future = user.futures.create!(period_from: Date.current.beginning_of_month)
    bucket = user.buckets.create!(
      bucketable: future,
      name: FUTURE_NAME,
      icon: FUTURE_ICON,
      colour: FUTURE_COLOUR
    )
    [
      Task.new(body: 'Read 12 books this year'),
      Note.new(body: 'Trip ideas for summer')
    ].each do |bulletable|
      user.bullets.create!(bucket: bucket, bulletable: bulletable, pops_on: nil)
    end
  end

  def ensure_loose_notes!
    existing = user.buckets.find_by(bucketable_type: 'Collection', name: LOOSE_NOTES_NAME.downcase)
    return existing if existing.present?

    collection = Collection.create!
    user.buckets.create!(bucketable: collection, name: LOOSE_NOTES_NAME)
  end
end
