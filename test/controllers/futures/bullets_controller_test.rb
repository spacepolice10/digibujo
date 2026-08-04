# frozen_string_literal: true

require 'test_helper'

class Futures::BulletsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    @future = ensure_future!(@user)
  end

  test 'index lists unplanned bullets in chronological order' do
    older = create_bullet!(@user,
      bulletable: Note.new(body: 'Someday note'),
      bucket_id: @future.bucket.id
    )
    older.update_columns(created_at: 2.days.ago)
    newer = create_bullet!(@user,
      bulletable: Note.new(body: 'Newer someday note'),
      bucket_id: @future.bucket.id
    )
    newer.update_columns(created_at: 1.day.ago)

    get future_bullets_path(@future)

    assert_response :success
    assert_operator response.body.index('Someday note'), :<, response.body.index('Newer someday note')
  end

  test 'index returns a full page of rows' do
    Bullet::Pageable::PAGE_SIZE.times do |i|
      create_bullet!(@user,
        bulletable: Task.new(body: "Goal #{i}"),
        bucket_id: @future.bucket.id
      )
    end

    get future_bullets_path(@future)

    assert_response :success
    assert_select '.bullet', Bullet::Pageable::PAGE_SIZE
  end

  test 'before returns an older page of bullets' do
    older = create_bullet!(@user,
      bulletable: Task.new(body: 'Older goal'),
      bucket_id: @future.bucket.id
    )
    older.update_columns(created_at: 2.days.ago)
    newer = create_bullet!(@user,
      bulletable: Task.new(body: 'Newer goal'),
      bucket_id: @future.bucket.id
    )
    newer.update_columns(created_at: 1.day.ago)

    get future_bullets_path(@future, before: newer.id)

    assert_response :success
    assert_match 'Older goal', response.body
    assert_no_match 'Newer goal', response.body
  end

  test 'before returns no content when the cursor is missing' do
    get future_bullets_path(@future, before: 0)

    assert_response :no_content
  end

  test 'foreign future returns not found' do
    other = ensure_future!(users(:two), period_from: Date.new(2026, 1, 1))

    get future_bullets_path(other)

    assert_response :not_found
  end
end
