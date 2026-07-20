# frozen_string_literal: true

require 'test_helper'

class Daylog::MoodEntityTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    ensure_daylog!(@user)
    @daylog = @user.reload.daylog
  end

  test 'creates mood entity for a day' do
    entity = @daylog.mood_entities.create!(date: Date.current, mood: :inspired)

    assert_equal 'inspired', entity.mood
    assert_equal '✨', entity.marker
  end

  test 'enforces one entity per date' do
    @daylog.mood_entities.create!(date: Date.current, mood: :positive)
    duplicate = @daylog.mood_entities.new(date: Date.current, mood: :negative)

    assert_not duplicate.valid?
  end
end
