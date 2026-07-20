# frozen_string_literal: true

class Daylog < ApplicationRecord
  include Bucketable

  belongs_to :user
  has_many :mood_entities, class_name: 'Daylog::MoodEntity', dependent: :destroy
  has_many :pictures, class_name: 'Daylog::Picture', dependent: :destroy

  validates :user_id, uniqueness: true
end
