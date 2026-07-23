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

  test 'current future shows spread when covering future exists' do
    future = ensure_future!(@user)
    create_bullet!(@user,
      bulletable: Note.new(body: 'Someday idea'),
      bucket_id: future.bucket.id
    )

    get current_future_path

    assert_response :success
    assert_match 'Someday idea', response.body
    assert_match 'Unplanned', response.body
  end

  test 'show returns not found for another users future log' do
    other_user = users(:two)
    future = ensure_future!(other_user)

    get future_path(future)

    assert_response :not_found
  end

  test 'show by id loads the requested spread when multiple futures exist' do
    first = ensure_future!(@user, period_from: Date.new(2026, 1, 1))
    second = ensure_future!(@user, period_from: Date.new(2026, 7, 1))
    create_bullet!(@user,
      bulletable: Task.new(body: 'First-half goal'),
      bucket_id: first.bucket.id
    )
    create_bullet!(@user,
      bulletable: Task.new(body: 'Second-half goal'),
      bucket_id: second.bucket.id
    )

    get future_path(first)

    assert_response :success
    assert_match 'First-half goal', response.body
    assert_no_match 'Second-half goal', response.body
  end
end
