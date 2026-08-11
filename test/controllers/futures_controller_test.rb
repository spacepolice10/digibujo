# frozen_string_literal: true

require 'test_helper'

class FuturesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test 'current future shows empty when user has no future logs' do
    get current_future_path

    assert_response :success
    assert_match 'No future log yet', response.body
    assert_select "a.button--primary[href=?]", new_future_path
  end

  test 'current future shows unplanned chat list when covering future exists' do
    future = ensure_future!(@user)
    create_bullet!(@user,
      bulletable: Note.new, body: 'Someday idea',
      bucket_id: future.bucket.id
    )
    create_bullet!(@user,
      bulletable: Event.new, body: 'Month card event',
      bucket_id: future.bucket.id,
      pops_on: future.period_from
    )

    get current_future_path

    assert_response :success
    assert_match 'Someday idea', response.body
    assert_no_match 'Month card event', response.body
    assert_select '.chat--window'
    assert_select '.future--grid', count: 0
    assert_select "#future_bullets_unplanned_container.chat--scroller[data-controller~='chat-scroll']"
    assert_select '[data-controller~="chat-scroll"][data-chat-scroll-path-value=?]', future_bullets_path(future)
    assert_select 'div#future_bullets_unplanned_composer.composer[data-controller~="composer"]'
    assert_select '.bullets-form--create', count: 0
  end

  test 'current future renders a load-more trigger over one full page' do
    future = ensure_future!(@user)
    Bullet::Pageable::PAGE_SIZE.times do |i|
      create_bullet!(@user,
        bulletable: Task.new, body: "Goal #{i}",
        bucket_id: future.bucket.id
      )
    end

    get current_future_path

    assert_response :success
    assert_select 'div#future_bullets_unplanned_container > .chat--load-more-trigger[data-chat-scroll-target=trigger]', count: 1
  end

  test 'show returns not found for another users future log' do
    other_user = users(:two)
    future = ensure_future!(other_user)

    get future_path(future)

    assert_response :not_found
  end

  test 'show by id loads the requested future when multiple futures exist' do
    first = ensure_future!(@user, period_from: Date.new(2026, 1, 1))
    second = ensure_future!(@user, period_from: Date.new(2026, 7, 1))
    create_bullet!(@user,
      bulletable: Task.new, body: 'First-half goal',
      bucket_id: first.bucket.id
    )
    create_bullet!(@user,
      bulletable: Task.new, body: 'Second-half goal',
      bucket_id: second.bucket.id
    )

    get future_path(first)

    assert_response :success
    assert_match 'First-half goal', response.body
    assert_no_match 'Second-half goal', response.body
  end
end
