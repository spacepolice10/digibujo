# frozen_string_literal: true

class Daylog < ApplicationRecord
  include Bucketable

  belongs_to :user
  has_many :mood_entities, class_name: 'Daylog::MoodEntity', dependent: :destroy
  has_many :pictures, class_name: 'Daylog::Picture', dependent: :destroy

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

  def pick_mood(date:, mood:)
    entity = mood_entities.find_or_initialize_by(date: date)
    entity.mood = mood
    entity.save!
    entity
  end

  def remove_mood(date:)
    mood_entities.find_by!(date: date).destroy!
  end

  def remove_picture(date:)
    pictures.find_by!(date: date).destroy!
  end

  def mood_entities_by_date(dates)
    mood_entities.where(date: dates).index_by(&:date)
  end

  def pictures_by_date(dates)
    pictures.where(date: dates).index_by(&:date)
  end
end
