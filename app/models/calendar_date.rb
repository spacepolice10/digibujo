# frozen_string_literal: true

class CalendarDate < ApplicationRecord
  belongs_to :user
  has_one :mood_entity, class_name: 'CalendarDate::MoodEntity', dependent: :destroy
  has_one :picture, class_name: 'CalendarDate::Picture', dependent: :destroy

  validates :date, uniqueness: { scope: :user_id }
end
