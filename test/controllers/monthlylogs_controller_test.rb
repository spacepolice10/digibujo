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
    assert_select "form[action=?]", monthlylogs_path
  end

  test 'monthly bucket shows spread shell when current exists' do
    monthlylog = create_monthlylog!(@user, name: 'june')
    create_bullet!(@user,
                   bulletable: Task.new, body: 'Unplanned task',
                   bucket_id: monthlylog.bucket.id)

    get current_monthlylog_path

    assert_response :success
    assert_match 'Unplanned', response.body
    assert_select 'turbo-frame#monthlylog_unplanned[src=?]', monthlylog_bullets_path(monthlylog)
    assert_select 'turbo-frame#monthlylog_date[src=?]',
                  monthlylog_bullets_path(monthlylog, date: Date.current.iso8601)
    assert_no_match 'Unplanned task', response.body
  end

  test 'show returns not found for another users monthly bucket' do
    other_user = users(:two)
    monthlylog = create_monthlylog!(other_user, name: 'private spread')

    get monthlylog_path(monthlylog)

    assert_response :not_found
  end

  test 'show by id renders calendar and lazy bullet frames without dated bodies' do
    monthlylog = create_monthlylog!(@user, name: 'june')
    day = Date.current.beginning_of_month + 2.days
    create_bullet!(@user,
                   bulletable: Event.new, body: 'Dentist',
                   bucket_id: monthlylog.bucket.id,
                   pops_on: day)

    get monthlylog_path(monthlylog)

    assert_response :success
    assert_select '.monthlylog--calendar-grid'
    assert_select '.monthlylog--indicator:not([hidden])', minimum: 1
    assert_select 'turbo-frame#monthlylog_date[src=?]',
                  monthlylog_bullets_path(monthlylog, date: Date.current.iso8601)
    assert_no_match 'Dentist', response.body
  end

  test 'monthlylog show has calendar cells, frames, and unplanned panel' do
    monthlylog = create_monthlylog!(@user, name: 'june')
    day = Date.current.beginning_of_month + 2.days
    create_bullet!(@user,
                   bulletable: Task.new, body: 'Planned task',
                   bucket_id: monthlylog.bucket.id,
                   pops_on: day)

    get monthlylog_path(monthlylog)

    assert_response :success
    assert_select '.monthlylog--spread'
    assert_select '.monthlylog--date-cell', minimum: 28
    assert_select '.monthlylog--date-band', count: 0
    assert_select '[data-controller~=scroll]', count: 0
    assert_select 'a.monthlylog--date-item[href=?]',
                  monthlylog_bullets_path(monthlylog, date: day.iso8601)
    assert_select 'turbo-frame#monthlylog_unplanned[src=?]', monthlylog_bullets_path(monthlylog)
    assert_select '.monthlylog--unplanned'
    assert_select '.bullets-form--dock', count: 0
    assert_select 'dialog#monthlylog_composer', count: 0
    assert_select "turbo-frame#date_#{Date.current.iso8601}_bullets_composer.composer"
    assert_select '[data-controller~=monthlylog-composer]'
    assert_select '.monthlylog--composer-dock', count: 2
    assert_select '.monthlylog--pane', count: 2
    assert_select 'button.monthlylog--create-bullet', count: 2
    assert_select '.monthlylog--composer-park turbo-frame.composer'
    assert_select '[data-controller~=pops-drop]', minimum: 28
    assert_select '[data-controller~=monthlylog-calendar-drop-optimistic]', minimum: 28
  end

  test 'mobile monthlylog show uses date strip instead of grid' do
    monthlylog = create_monthlylog!(@user, name: 'june')
    day = Date.current.beginning_of_month
    create_bullet!(@user,
                   bulletable: Task.new, body: 'Planned mobile task',
                   bucket_id: monthlylog.bucket.id,
                   pops_on: day)
    create_bullet!(@user,
                   bulletable: Note.new, body: 'Unplanned mobile note',
                   bucket_id: monthlylog.bucket.id)

    get monthlylog_path(monthlylog), headers: { 'User-Agent' => MOBILE_UA }

    assert_response :success
    assert_select '.monthlylog--page-mobile'
    assert_select '.monthlylog--spread-sections'
    assert_select '.monthlylog--section.monthlylog--calendar'
    assert_select '.monthlylog--section.monthlylog--unplanned'
    assert_select '.monthlylog--inline-calendar'
    assert_select '.monthlylog--calendar-grid', count: 0
    assert_select 'main.layout--surface', count: 0
    assert_select '.monthlylog--date-cell-inline', minimum: 28
    assert_select '.monthlylog--date-cell-inline.is-current', count: 1
    assert_select '.monthlylog--unplanned'
    assert_select '[role=tab]', count: 0
    assert_select 'turbo-frame#monthlylog_date[src]'
    assert_select 'turbo-frame#monthlylog_unplanned[src]'
    assert_select 'dialog#monthlylog_composer', count: 0
    assert_select '.monthlylog--calendar [data-controller~=pops-drop]', count: 0
    assert_select '[data-controller~=monthlylog-calendar-drop-optimistic]', count: 0
    assert_select '[data-controller~=monthlylog-inline-calendar]'
    assert_select '.monthlylog--divider', count: 0
    assert_select '.chat--window.chat--window--embedded', count: 2
    assert_select '.monthlylog--pane', count: 0
    assert_select '.monthlylog--composer-dock', count: 0
    assert_select '.monthlylog--composer-park turbo-frame.composer'
  end

  test 'empty current monthlylog shows provision placeholder' do
    get current_monthlylog_path

    assert_response :success
    assert_match 'No monthly spread yet', response.body
    assert_select "form[action=?][method=post]", monthlylogs_path do
      assert_select "button", text: 'Create monthly spread'
    end
  end

  test 'create provisions current month' do
    @user.monthlylogs.destroy_all

    assert_difference -> { Monthlylog.count }, 1 do
      post monthlylogs_path
    end

    created = Monthlylog.last
    assert_equal Date.current.beginning_of_month, created.period_from
    assert_redirected_to monthlylog_path(created)
  end

  test 'create is idempotent when current month already exists' do
    existing = create_monthlylog!(@user, name: 'june')

    assert_no_difference -> { Monthlylog.count } do
      post monthlylogs_path
    end

    assert_redirected_to monthlylog_path(existing)
  end

  test 'show paints calendar_date picture as date cell thumb' do
    ensure_daylog!(@user)
    calendar_date = @user.calendar_dates.create!(date: Date.current)
    picture = calendar_date.build_picture
    picture.picture.attach(
      io: StringIO.new(Base64.decode64(
                         'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='
                       )),
      filename: 'day.png',
      content_type: 'image/png'
    )
    picture.save!
    monthlylog = create_monthlylog!(@user, name: Date.current.strftime('%B %Y'))

    get monthlylog_path(monthlylog)

    assert_response :success
    assert_select '.monthlylog--date-preview', count: 1
  end

  test 'show by id loads the requested spread shell when multiple months exist' do
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
                   bulletable: Task.new, body: 'June-only task',
                   bucket_id: june.bucket.id)
    create_bullet!(@user,
                   bulletable: Task.new, body: 'July-only task',
                   bucket_id: july.bucket.id)

    get monthlylog_path(june)

    assert_response :success
    assert_select 'title', text: /june 2026/i
    assert_select 'turbo-frame#monthlylog_unplanned[src=?]', monthlylog_bullets_path(june)
    assert_select 'turbo-frame#monthlylog_unplanned[src=?]', monthlylog_bullets_path(july), count: 0
    assert_select 'turbo-frame#monthlylog_date[src=?]',
                  monthlylog_bullets_path(june, date: Date.new(2026, 6, 1).iso8601)
    assert_equal "/monthlylogs/#{june.id}", monthlylog_path(june)
  end
end
