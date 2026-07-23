# frozen_string_literal: true

require 'test_helper'

class MonthlylogsControllerTest < ActionDispatch::IntegrationTest
  MOBILE_UA = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)'

  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test 'monthly bucket shows empty when user has no spreads' do
    get current_monthlylog_path

    assert_response :success
    assert_match 'No monthly spread yet', response.body
  end

  test 'monthly bucket shows spread when current exists' do
    monthlylog = create_monthlylog!(@user, name: 'june')
    create_bullet!(@user,
      bulletable: Task.new(body: 'Unplanned task'),
      bucket_id: monthlylog.bucket.id
    )

    get current_monthlylog_path

    assert_response :success
    assert_match 'Unplanned task', response.body
    assert_match 'Unplanned', response.body
  end

  test 'show returns not found for another users monthly bucket' do
    other_user = users(:two)
    monthlylog = create_monthlylog!(other_user, name: 'private spread')

    get monthlylog_path(monthlylog)

    assert_response :not_found
  end

  test 'show by id lists dated bullets in by_date column' do
    monthlylog = create_monthlylog!(@user, name: 'june')
    day = Date.current.beginning_of_month + 2.days
    create_bullet!(@user,
      bulletable: Event.new(body: 'Dentist'),
      bucket_id: monthlylog.bucket.id,
      pops_on: day
    )

    get monthlylog_path(monthlylog)

    assert_response :success
    assert_match 'Dentist', response.body
  end

  test 'monthlylog show has date bands, add links, and unplanned panel' do
    monthlylog = create_monthlylog!(@user, name: 'june')
    day = Date.current.beginning_of_month + 2.days
    create_bullet!(@user,
      bulletable: Task.new(body: 'Planned task'),
      bucket_id: monthlylog.bucket.id,
      pops_on: day
    )

    get monthlylog_path(monthlylog)

    assert_response :success
    assert_select '.monthlylog--spread'
    assert_select '.monthlylog--date-band', minimum: 28
    assert_select '.monthlylog--calendar', text: /Planned task/
    assert_select "a.bullets-form--create-button--task[href=?]",
                  new_bullet_path(
                    pops_on: day,
                    bucket_id: monthlylog.bucket.id,
                    bulletable_type: 'Task'
                  )
    assert_select "a.bullets-form--create-button--event[href=?]",
                  new_bullet_path(
                    pops_on: day,
                    bucket_id: monthlylog.bucket.id,
                    bulletable_type: 'Event'
                  )
    assert_select '.monthlylog--unplanned a.bullets-form--create-button--note'
    assert_select '.monthlylog--unplanned a.bullets-form--create-button--task', count: 0
    assert_select '.monthlylog--unplanned a.bullets-form--create-button--event', count: 0
    assert_select '.monthlylog--unplanned a.bullets-form--create-button--voice', count: 0
    assert_select '.bullets-form--dock', count: 0
    assert_select '.monthlylog--unplanned'
    assert_select 'dialog#monthlylog_composer.bullet-composer--dialog'
    assert_select 'dialog#monthlylog_composer turbo-frame#monthlylog_bullets_unplanned_composer'
  end

  test 'monthlylog unplanned bullets render as compact rows without metadata tags' do
    monthlylog = create_monthlylog!(@user, name: 'june')
    bullet = create_bullet!(@user,
      bulletable: Task.new(body: 'Pinned spread task'),
      bucket_id: monthlylog.bucket.id
    )
    PinnedEntity.create!(user: @user, pinnable: bullet)

    get monthlylog_path(monthlylog)

    assert_response :success
    assert_select "turbo-frame##{dom_id(bullet)}.bullet", text: /Pinned spread task/
    assert_select "turbo-frame##{dom_id(bullet)}.bullet > .bullet--marker", count: 1
    assert_select "turbo-frame##{dom_id(bullet)}.bullet .bullet--tags", count: 0
    assert_select "turbo-frame##{dom_id(bullet)}.bullet .bullet--metadata", count: 0
  end


  test 'monthlylog unplanned bullets render body text' do
    monthlylog = create_monthlylog!(@user, name: 'june')
    create_bullet!(@user,
      bulletable: Task.new(body: 'Plain task'),
      bucket_id: monthlylog.bucket.id
    )
    create_bullet!(@user,
      bulletable: Note.new(body: '<p>Expanded detail</p>'),
      bucket_id: monthlylog.bucket.id
    )

    get monthlylog_path(monthlylog)

    assert_response :success
    assert_match 'Plain task', response.body
    assert_match 'Expanded detail', response.body
  end

  test 'dated monthlylog tasks appear in date bands' do
    monthlylog = create_monthlylog!(@user, name: 'june')
    day = Date.current.beginning_of_month + 2.days
    bullet = create_bullet!(@user,
      bulletable: Task.new(body: 'Buy ointment'),
      bucket_id: monthlylog.bucket.id,
      pops_on: day
    )
    bullet.bulletable.complete!

    get monthlylog_path(monthlylog)

    assert_response :success
    assert_select '.monthlylog--calendar', text: /Buy ointment/
  end


  test 'mobile monthlylog show keeps both panels without tabs' do
    monthlylog = create_monthlylog!(@user, name: 'june')
    day = Date.current.beginning_of_month
    create_bullet!(@user,
      bulletable: Task.new(body: 'Planned mobile task'),
      bucket_id: monthlylog.bucket.id,
      pops_on: day
    )
    create_bullet!(@user,
      bulletable: Note.new(body: 'Unplanned mobile note'),
      bucket_id: monthlylog.bucket.id
    )

    get monthlylog_path(monthlylog), headers: { 'User-Agent' => MOBILE_UA }

    assert_response :success
    assert_select '.monthlylog--spread'
    assert_select '.monthlylog--calendar'
    assert_select '.monthlylog--unplanned'
    assert_select '[role=tab]', count: 0
    assert_match 'Planned mobile task', response.body
    assert_match 'Unplanned mobile note', response.body
    assert_select 'dialog#monthlylog_composer.bullet-composer--dialog'
    assert_select '[data-controller~=pops-drop]', minimum: 1
  end

  test 'mobile monthlylog unplanned bullets render without drag' do
    monthlylog = create_monthlylog!(@user, name: 'june')
    create_bullet!(@user,
      bulletable: Task.new(body: 'Mobile spread task'),
      bucket_id: monthlylog.bucket.id
    )

    get monthlylog_path(monthlylog), headers: { 'User-Agent' => MOBILE_UA }

    assert_response :success
    assert_match 'Mobile spread task', response.body
    assert_select '.bullet[data-layout="spread"]', count: 0
    assert_select 'turbo-frame.bullet[draggable="true"]', count: 0
    assert_select '.bullet--marker', minimum: 1
  end

  test 'monthlylog date rails link to daylog' do
    monthlylog = create_monthlylog!(@user, name: 'june')
    day = Date.current.beginning_of_month + 4.days

    get monthlylog_path(monthlylog)

    assert_response :success
    assert_select "a.monthlylog--date-item[href=?]", daylog_path(date: day.iso8601)
  end

  test 'new form defaults to first available selectable month' do
    @user.monthlylogs.destroy_all

    get new_monthlylog_path

    assert_response :success
    assert_select "input[name='monthlylog[period_from]'][type=radio]", count: 13
    start = Date.current.beginning_of_month - 1.month
    assert_select "input[name='monthlylog[period_from]'][value=?][checked]",
                  start.iso8601
  end

  test 'new form disables occupied months and selects first available' do
    create_monthlylog!(@user, name: 'june')
    occupied = Date.current.beginning_of_month
    start = Date.current.beginning_of_month - 1.month
    expected = (0..12).map { |i| start + i.months }.find { |m| m != occupied }

    get new_monthlylog_path

    assert_response :success
    assert_select "input[name='monthlylog[period_from]'][value=?][disabled]",
                  occupied.iso8601
    assert_select "input[name='monthlylog[period_from]'][value=?][checked]", expected.iso8601
    assert_select 'label.monthlylog--period-option--disabled'
  end

  test 'create rejects duplicate month' do
    create_monthlylog!(@user, name: 'june')

    assert_no_difference -> { Monthlylog.count } do
      post monthlylogs_path, params: {
        monthlylog: { period_from: Date.current.beginning_of_month.iso8601 }
      }
    end

    assert_response :unprocessable_entity
    assert_match 'has already been taken', response.body
  end

  test 'create succeeds for available month' do
    @user.monthlylogs.destroy_all
    month = Date.current.beginning_of_month

    assert_difference -> { Monthlylog.count }, 1 do
      post monthlylogs_path, params: {
        monthlylog: { period_from: month.iso8601 }
      }
    end

    created = Monthlylog.last
    assert_redirected_to monthlylog_path(created)
  end

  test 'show includes mood tracker from daylog' do
    ensure_daylog!(@user)
    @user.daylog.mood_entities.create!(date: Date.current, mood: :inspired)
    monthlylog = create_monthlylog!(@user, name: Date.current.strftime('%B %Y'))

    get monthlylog_path(monthlylog)

    assert_response :success
    assert_select 'section.monthlylog--mood'
    assert_match '✨', response.body
  end

  test 'show by id loads the requested spread when multiple months exist' do
    june = create_monthlylog!(
      @user,
      name: 'June 2026',
      period_from: Date.new(2026, 6, 1),
      period_to: Date.new(2026, 6, 30)
    )
    july = create_monthlylog!(
      @user,
      name: 'July 2026',
      period_from: Date.new(2026, 7, 1),
      period_to: Date.new(2026, 7, 31)
    )
    create_bullet!(@user,
      bulletable: Task.new(body: 'June-only task'),
      bucket_id: june.bucket.id
    )
    create_bullet!(@user,
      bulletable: Task.new(body: 'July-only task'),
      bucket_id: july.bucket.id
    )

    get monthlylog_path(june)

    assert_response :success
    assert_match 'June-only task', response.body
    assert_no_match 'July-only task', response.body
    assert_equal "/monthlylogs/#{june.id}", monthlylog_path(june)
  end
end
