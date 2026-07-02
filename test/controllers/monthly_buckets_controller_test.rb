# frozen_string_literal: true

require 'test_helper'

class MonthlyBucketsControllerTest < ActionDispatch::IntegrationTest
  MOBILE_UA = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)'

  setup do
    @user = users(:one)
    ensure_future_bucket!(@user)
    sign_in_as @user
  end

  test 'monthly bucket shows empty when user has no spreads' do
    get current_monthly_bucket_path

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

    get current_monthly_bucket_path

    assert_response :success
    assert_match 'Unplanned task', response.body
    assert_match 'Unplanned', response.body
  end

  test 'show returns not found for another users monthly bucket' do
    other_user = users(:two)
    monthly_bucket = create_monthly_bucket!(other_user, name: 'private spread')

    get monthly_bucket_path(monthly_bucket)

    assert_response :not_found
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

  test 'monthly bucket spread has date add menu and composer frames' do
    monthly_bucket = create_monthly_bucket!(@user, name: 'june')
    day = Date.current.beginning_of_month + 2.days
    @user.bullets.create!(
      bulletable: Task.create!,
      body: 'Planned task',
      bucket_id: monthly_bucket.bucket.id,
      pops_on: day
    )

    get monthly_bucket_path(monthly_bucket)

    assert_response :success
    assert_select 'a[aria-label=?]', 'Add Event'
    assert_select 'a[aria-label=?]', 'Add Task'
    assert_select 'dialog#monthly_bucket_composer.monthly-bucket--composer-dialog'
    assert_select 'dialog#monthly_bucket_composer turbo-frame#bullet_composer[data-controller=?]', 'composer'
    assert_select "turbo-frame##{dom_id(monthly_bucket, day)}", count: 0
    assert_match 'Planned task', response.body
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
    assert_select '.bullet--monthly-bucket .bullet--monthly-bucket-marker', count: 1
    assert_select '.bullet--monthly-bucket .bullet--marker', count: 0
    assert_select '.bullet--monthly-bucket .bullet--tags', count: 0
    assert_select '.bullet--monthly-bucket .bullet--metadata', count: 0
  end

  test 'monthly bucket bullets link to show page' do
    monthly_bucket = create_monthly_bucket!(@user, name: 'june')
    plain = @user.bullets.create!(
      bulletable: Task.create!,
      body: 'Plain task',
      bucket_id: monthly_bucket.bucket.id
    )
    with_rich_body = @user.bullets.create!(
      bulletable: Note.create!,
      body: '<p>Expanded detail</p>',
      bucket_id: monthly_bucket.bucket.id
    )

    get monthly_bucket_path(monthly_bucket)

    assert_response :success
    assert_select "a.bullet--monthly-bucket-link[href='#{bullet_path(plain)}']", text: /Plain task/
    assert_select "a.bullet--monthly-bucket-link[href='#{bullet_path(with_rich_body)}']", text: /Expanded detail/
    assert_select '.bullet--monthly-bucket-extra', count: 0
  end

  test 'completed monthly bucket tasks are marked completed' do
    monthly_bucket = create_monthly_bucket!(@user, name: 'june')
    day = Date.current.beginning_of_month + 2.days
    bullet = @user.bullets.create!(
      bulletable: Task.create!,
      body: 'Buy ointment',
      bucket_id: monthly_bucket.bucket.id,
      pops_on: day
    )
    bullet.bulletable.complete!

    get monthly_bucket_path(monthly_bucket)

    assert_response :success
    assert_select "turbo-frame##{dom_id(bullet)}[data-bullet-completed]"
    assert_select "a.bullet--monthly-bucket-link[href='#{bullet_path(bullet)}']", text: /Buy ointment/
  end

  test 'mobile monthly bucket renders planned and unplanned tabs' do
    monthly_bucket = create_monthly_bucket!(@user, name: 'june')
    day = Date.current.beginning_of_month
    @user.bullets.create!(
      bulletable: Task.create!,
      body: 'Planned mobile task',
      bucket_id: monthly_bucket.bucket.id,
      pops_on: day
    )
    @user.bullets.create!(
      bulletable: Note.create!,
      body: 'Unplanned mobile note',
      bucket_id: monthly_bucket.bucket.id
    )

    get monthly_bucket_path(monthly_bucket), headers: { 'User-Agent' => MOBILE_UA }

    assert_response :success
    assert_select '.monthly-bucket--page-mobile'
    assert_select '.monthly-bucket--monthly-sections button[role=tab]', count: 2
    assert_select 'button[data-monthly-sections-section=?]', 'days', text: 'Planned'
    assert_select 'button[data-monthly-sections-section=?]', 'unplanned', text: 'Unplanned'
    assert_select '.monthly-bucket--calendar.monthly-bucket--side-active', count: 1
    assert_select '.monthly-bucket--unplanned[hidden]', count: 1
    assert_match 'Planned mobile task', response.body
    assert_match 'Unplanned mobile note', response.body
    assert_select '[data-controller=?]', 'pops-drop', count: 0
  end

  test 'mobile monthly bucket bullets render full rows without drag' do
    monthly_bucket = create_monthly_bucket!(@user, name: 'june')
    @user.bullets.create!(
      bulletable: Task.create!,
      body: 'Mobile spread task',
      bucket_id: monthly_bucket.bucket.id
    )

    get monthly_bucket_path(monthly_bucket), headers: { 'User-Agent' => MOBILE_UA }

    assert_response :success
    assert_match 'Mobile spread task', response.body
    assert_select '.bullet--monthly-bucket', count: 0
    assert_select 'turbo-frame.bullet[draggable="true"]', count: 0
    assert_select '.bullet--task-marker', count: 1
  end

  test 'monthly bucket date labels link to daylog' do
    monthly_bucket = create_monthly_bucket!(@user, name: 'june')
    day = Date.current.beginning_of_month + 4.days

    get monthly_bucket_path(monthly_bucket)

    assert_response :success
    assert_select "a.monthly-bucket--date-number[href='#{daylog_path(date: day.iso8601)}']",
                  text: /#{day.day}.*#{day.strftime('%a')}/
  end

  test 'new form defaults to current month' do
    get new_monthly_bucket_path

    assert_response :success
    assert_select "input[name='monthly_bucket[month]'][type=radio]", count: 6
    assert_select "input[name='monthly_bucket[month]'][value=?][checked]",
                  Date.current.beginning_of_month.iso8601
    assert_select "input[name='monthly_bucket[month]'][item_wrapper_tag]", count: 0
    assert_select "label.monthly-bucket--period-option[for=?]", "monthly_bucket_month_#{Date.current.beginning_of_month.iso8601}"
  end

  test 'new form disables occupied months and selects first available' do
    create_monthly_bucket!(@user, name: 'june')
    next_month = Date.current.beginning_of_month.next_month

    get new_monthly_bucket_path

    assert_response :success
    assert_select "input[name='monthly_bucket[month]'][value=?][disabled]",
                  Date.current.beginning_of_month.iso8601
    assert_select "input[name='monthly_bucket[month]'][value=?][checked]", next_month.iso8601
    assert_select 'label.monthly-bucket--period-option--disabled'
  end

  test 'create rejects duplicate month' do
    create_monthly_bucket!(@user, name: 'june')

    assert_no_difference -> { MonthlyBucket.count } do
      post monthly_buckets_path, params: {
        monthly_bucket: { month: Date.current.beginning_of_month.iso8601 }
      }
    end

    assert_response :unprocessable_entity
    assert_match 'has already been taken', response.body
  end

  test 'create rejects month outside selectable range' do
    assert_no_difference -> { MonthlyBucket.count } do
      post monthly_buckets_path, params: {
        monthly_bucket: { month: (Date.current.beginning_of_month + 6.months).iso8601 }
      }
    end

    assert_response :unprocessable_entity
    assert_match 'must be within the next six months', response.body
  end

  test 'show by id loads the requested spread when multiple months exist' do
    june = create_monthly_bucket!(
      @user,
      name: 'June 2026',
      period_from: Date.new(2026, 6, 1),
      period_to: Date.new(2026, 6, 30)
    )
    july = create_monthly_bucket!(
      @user,
      name: 'July 2026',
      period_from: Date.new(2026, 7, 1),
      period_to: Date.new(2026, 7, 31)
    )
    @user.bullets.create!(
      bulletable: Task.create!,
      body: 'June-only task',
      bucket_id: june.bucket.id
    )
    @user.bullets.create!(
      bulletable: Task.create!,
      body: 'July-only task',
      bucket_id: july.bucket.id
    )

    get monthly_bucket_path(june)

    assert_response :success
    assert_match 'June-only task', response.body
    assert_no_match 'July-only task', response.body
    assert_equal "/monthly_buckets/#{june.id}", monthly_bucket_path(june)
  end
end
