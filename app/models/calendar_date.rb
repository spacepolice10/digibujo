# frozen_string_literal: true

class CalendarDate < ApplicationRecord
  belongs_to :user
  has_one :mood_entity, class_name: 'CalendarDate::MoodEntity', dependent: :destroy
  has_one :picture, class_name: 'CalendarDate::Picture', dependent: :destroy
  has_many :tracker_statuses, class_name: 'Tracker::Status', dependent: :destroy

  validates :date, uniqueness: { scope: :user_id }

  def pick_mood(mood)
    entity = mood_entity || build_mood_entity
    entity.update!(mood: mood)
    entity
  end

  def remove_mood
    mood_entity&.destroy!
  end

  def remove_picture
    picture&.destroy!
  end

  def self.mood_entities_by_date(user, dates)
    user.calendar_dates.where(date: dates).includes(:mood_entity).filter_map { |cd|
      [cd.date, cd.mood_entity] if cd.mood_entity
    }.to_h
  end

  def self.pictures_by_date(user, dates)
    user.calendar_dates.where(date: dates).includes(:picture).filter_map { |cd|
      [cd.date, cd.picture] if cd.picture
    }.to_h
  end
end
