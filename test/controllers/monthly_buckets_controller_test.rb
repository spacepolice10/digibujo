# frozen_string_literal: true

require 'test_helper'

class MonthlyBucketsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test 'monthly bucket shows empty when user has no spreads' do
    get monthly_bucket_path

    assert_response :success
    assert_match 'No monthly spread yet', response.body
  end

  test 'monthly bucket shows spread when current exists' do
    monthly_bucket = create_monthly_bucket!(@user, name: 'june')
    @user.bullets.create!(
      bulletable: Task.create!,
      body: 'Unplanned task',
      bucket_id: monthly_bucket.bucket.id
    )

    get monthly_bucket_path

    assert_response :success
    assert_match 'Unplanned task', response.body
    assert_match 'Unplanned', response.body
  end

  test 'show by id lists dated bullets in by_date column' do
    monthly_bucket = create_monthly_bucket!(@user, name: 'june')
    day = Date.current.beginning_of_month + 2.days
    @user.bullets.create!(
      bulletable: Event.create!,
      body: 'Dentist',
      bucket_id: monthly_bucket.bucket.id,
      pops_on: day
    )

    get monthly_bucket_path(monthly_bucket)

    assert_response :success
    assert_match 'Dentist', response.body
  end

  test 'monthly bucket spread has no bulk menu or select checkboxes' do
    monthly_bucket = create_monthly_bucket!(@user, name: 'june')
    @user.bullets.create!(
      bulletable: Task.create!,
      body: 'Selectable compact',
      bucket_id: monthly_bucket.bucket.id
    )

    get monthly_bucket_path(monthly_bucket)

    assert_response :success
    assert_select '.bulk-menu', count: 0
    assert_select 'input[type=checkbox][data-bulk-menu-target=?]', 'checkbox', count: 0
  end

  test 'monthly bucket bullets render as single-line rows without metadata tags' do
    monthly_bucket = create_monthly_bucket!(@user, name: 'june')
    bullet = @user.bullets.create!(
      bulletable: Task.create!,
      body: 'Pinned spread task',
      bucket_id: monthly_bucket.bucket.id
    )
    PinnedEntity.create!(user: @user, pinnable: bullet)

    get monthly_bucket_path(monthly_bucket)

    assert_response :success
    assert_select '.bullet--monthly-bucket .bullet--line', text: 'Pinned spread task'
    assert_select '.bullet--monthly-bucket .bullet--tags', count: 0
    assert_select '.bullet--monthly-bucket .bullet--metadata', count: 0
  end

  test 'new form defaults to current month period' do
    get new_monthly_bucket_path

    assert_response :success
    assert_select "input[name='monthly_bucket[period_from]'][value=?]", Date.current.beginning_of_month.iso8601
    assert_select "input[name='monthly_bucket[period_to]'][value=?]", Date.current.end_of_month.iso8601
  end
end
