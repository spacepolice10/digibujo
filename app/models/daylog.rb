# frozen_string_literal: true

class Daylog < ApplicationRecord
  include Bucketable

  belongs_to :user

  validates :user_id, uniqueness: true

  def self.provision!(user)
    if (existing = user.daylog)
      return existing if existing.bucket

      user.buckets.create!(bucketable: existing, name: Onboarding::DAYLOG_NAME, icon: Onboarding::DAYLOG_ICON)
      return existing.reload
    end

    record = user.create_daylog!
    user.buckets.create!(bucketable: record, name: Onboarding::DAYLOG_NAME, icon: Onboarding::DAYLOG_ICON)
    record.reload
  end

  def mood_entities
    CalendarDate::MoodEntity.joins(:calendar_date).where(calendar_dates: { user_id: user_id })
  end

  def pictures
    CalendarDate::Picture.joins(:calendar_date).where(calendar_dates: { user_id: user_id })
  end

  def pick_mood(date:, mood:)
    calendar_date = user.calendar_dates.find_or_create_by!(date: date)
    entity = calendar_date.mood_entity || calendar_date.build_mood_entity
    entity.mood = mood
    entity.save!
    entity
  end

  def remove_mood(date:)
    calendar_date = user.calendar_dates.find_by!(date: date)
    calendar_date.mood_entity.destroy!
  end

  def remove_picture(date:)
    calendar_date = user.calendar_dates.find_by!(date: date)
    calendar_date.picture.destroy!
  end

  def mood_entities_by_date(dates)
    user.calendar_dates.where(date: dates).includes(:mood_entity).filter_map { |cd|
      [cd.date, cd.mood_entity] if cd.mood_entity
    }.to_h
  end

  def pictures_by_date(dates)
    user.calendar_dates.where(date: dates).includes(:picture).filter_map { |cd|
      [cd.date, cd.picture] if cd.picture
    }.to_h
  end
end
