# frozen_string_literal: true

require 'test_helper'

class DaylogsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    ensure_daylog!(@user)
  end

  test 'daylog without daylog shows create form' do
    @user.daylog.bucket.destroy!
    @user.reload

    get daylog_path

    assert_response :success
    assert_match 'No daily log yet', response.body
    assert_select "form[action=?]", daylog_path
    assert_match 'Create daylog', response.body
  end

  test 'create provisions daylog and redirects' do
    @user.daylog.bucket.destroy!
    @user.reload

    assert_difference -> { Daylog.where(user: @user).count }, 1 do
      post daylog_path
    end

    assert_redirected_to daylog_path
    assert_not_nil @user.reload.daylog
  end

  test 'daylog without date shows today' do
    card = create_bullet!(@user, bulletable: Task.new(body: 'Today card'), pops_on: Date.current)

    get daylog_path

    assert_response :success
    assert_match card.name, response.body
  end

  test 'daylog with year month day shows that day' do
    selected_date = Date.current - 2.days
    travel_to selected_date.in_time_zone.change(hour: 10) do
      create_bullet!(@user, bulletable: Task.new(body: 'That day'), pops_on: selected_date)
    end
    create_bullet!(@user, bulletable: Task.new(body: 'Today noise'), pops_on: Date.current)

    get daylog_path(date: selected_date.iso8601)

    assert_response :success
    assert_match 'That day', response.body
    assert_no_match 'Today noise', response.body
  end

  test 'daylog renders project attachment inside bullet body' do
    project = create_project!(@user, name: 'inline tag')
    body_html = ActionText::Content.new('<p>tagged note</p>').append_attachables(project).to_html
    create_bullet!(@user, bulletable: Note.new(body: body_html), pops_on: Date.current)

    get daylog_path

    assert_response :success
    assert_select "a.pill[href=?]", project_path(project), text: /inline tag/
  end

  test 'invalid calendar date returns not found' do
    get daylog_path(date: "#{Date.current.year}-02-30")

    assert_response :not_found
  end

  test 'daylog renders date navigation links' do
    selected_date = Date.current - 2.days

    get daylog_path(date: selected_date.iso8601)

    assert_response :success
    assert_select "a[href='#{daylog_path(date: (selected_date - 1.day).iso8601)}']" \
      "[data-action*='keydown.shift+left@document->hotkey#click'][data-hotkey='←']"
    assert_select "a[href='#{daylog_path(date: (selected_date + 1.day).iso8601)}']" \
      "[data-action*='keydown.shift+right@document->hotkey#click'][data-hotkey='→']"
    assert_select "button[popovertarget='pinned_list'][data-action*='keydown.shift+p@document->hotkey#click'][data-hotkey='P']"
  end

  test 'daylog header shows pending inbox when bullets await triage' do
    pending = Pending.provision!(@user)
    create_bullet!(@user, bucket: pending.bucket, bulletable: Note.new(body: 'Stashed'), pops_on: nil)

    get daylog_path

    assert_response :success
    assert_select '#pending_inbox.daylog--pending-inbox' do
      assert_select 'button.daylog--pending-inbox-trigger[popovertarget=pending_list]'
      assert_select '#pending_inbox_count.daylog--pending-count', text: '1'
      assert_select 'turbo-frame#pending_list[popover][src=?]', pending_path
    end
  end

  test 'daylog header pending count includes monthlylog bullets for today' do
    monthlylog = create_monthlylog!(@user, name: 'This month')
    create_bullet!(
      @user,
      bucket: monthlylog.bucket,
      bulletable: Task.new(body: 'Monthly today'),
      pops_on: Date.current
    )

    get daylog_path

    assert_response :success
    assert_select '#pending_inbox_count.daylog--pending-count', text: '1'
  end

  test 'daylog header hides pending inbox when empty' do
    Pending.provision!(@user)

    get daylog_path

    assert_response :success
    assert_select '#pending_inbox', count: 0
  end

  test 'daylog scopes bulk menu controls to the bullets list' do
    create_bullet!(@user, bulletable: Task.new(body: 'Selectable card'), pops_on: Date.current)

    get daylog_path

    assert_response :success
    assert_select '[data-controller~=?]', 'bullets-bulk', 0
    assert_select '[data-controller~=?]', 'bulk-menu' do
      assert_select '[data-bulk-menu-target=?]', 'list'
      assert_select '.bulk-menu[data-bulk-menu-target=?]', 'menu'
      assert_select 'input[type=checkbox][data-bulk-menu-target=?]', 'checkbox'
    end
  end

  test 'desktop daylog mounts the chat composer' do
    selected_date = Date.current - 2.days
    bucket_id = @user.daylog.bucket.id

    get daylog_path(date: selected_date.iso8601)

    assert_response :success
    assert_select 'dialog#daylog_composer', count: 0
    assert_select '#bullet_composer' do
      assert_select 'lexxy-editor[preset=note][toolbar=composer_toolbar]'
      # Toolbar precedes the editor so a Turbo body swap upgrades it first.
      assert_select 'lexxy-toolbar#composer_toolbar[data-upload=both] + .composer--field + .composer--chrome'
      assert_select '.composer--actions .composer--toolbar-toggle'
      assert_select '.composer--actions .composer--upload', false
      assert_select 'lexxy-prompt[trigger=?][name=project]', '#'
      assert_select "input[name='bullet[bucket_id]'][value=?]", bucket_id.to_s
      assert_select "input[name='bullet[pops_on]'][value=?]", selected_date.iso8601
      assert_select "input[name='bullet[bulletable_type]'][value=?]", 'Note'
      assert_select "input[name='list_id']", count: 0
      assert_select 'button[data-composer-type=?]', 'Task'
      assert_select 'button[data-composer-type=?]', 'Event'
      assert_select '.composer--record'
      assert_select '[data-voice-player-target=?]', 'playIcon'
      assert_select '[data-voice-player-target=?]', 'stopIcon'
    end
    assert_no_match(/Add bullet/, response.body)
  end

  test 'mobile daylog mounts the chat composer' do
    selected_date = Date.current - 2.days
    mobile_ua = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)'

    get daylog_path(date: selected_date.iso8601), headers: { 'User-Agent' => mobile_ua }

    assert_response :success
    assert_select 'dialog#daylog_composer', count: 0
    assert_select '#bullet_composer lexxy-editor[preset=note]'
  end

  test 'mobile daylog keeps the day photo out of the DOM until shown' do
    date = Date.current
    picture = @user.daylog.pictures.new(date: date)
    picture.picture.attach(
      io: StringIO.new(Base64.decode64(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='
      )),
      filename: 'day.png',
      content_type: 'image/png'
    )
    picture.save!

    get daylog_path, headers: { 'User-Agent' => 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0)' }

    assert_response :success
    assert_select "#daylog_photo_card_#{date.iso8601}"
    assert_select '.daylog--photo-card', count: 0
    assert_select '.daylog--photo-card-image', count: 0
    assert_select '.daylog--picture [aria-label="Show photo"]'
    assert_select '[data-controller~=daylog-photo][data-daylog-photo-lazy-value=true]'
    assert_select "[data-daylog-photo-url-value=?]", daylog_picture_path(date: date.iso8601)
  end

  test 'desktop daylog embeds the day photo card when attached' do
    date = Date.current
    picture = @user.daylog.pictures.new(date: date)
    picture.picture.attach(
      io: StringIO.new(Base64.decode64(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='
      )),
      filename: 'day.png',
      content_type: 'image/png'
    )
    picture.save!

    get daylog_path

    assert_response :success
    assert_select '.daylog--photo-card'
    assert_select '.daylog--photo-card-image'
    assert_select '[data-controller~=daylog-photo][data-daylog-photo-lazy-value=false]'
  end

  test 'root path is home' do
    get root_path

    assert_response :success
  end

  test 'daylog shows today bullets' do
    card = create_bullet!(@user, bulletable: Task.new(body: 'Root today'), pops_on: Date.current)

    get daylog_path

    assert_response :success
    assert_match card.name, response.body
  end

  test 'desktop daylog renders digibujo menu in header' do
    get daylog_path

    assert_response :success
    assert_select 'header.header .header--menu' do
      assert_select 'button.button--accent[popovertarget=?]', 'header_menu', text: 'Digibujo'
      assert_select '#header_menu.dropdown-body[popover]'
      assert_select 'form.search--form[action=?]', search_path
      assert_select 'turbo-frame#menu_search'
    end
  end

  test 'mobile daylog omits header and renders tab bar' do
    get daylog_path, headers: { 'User-Agent' => 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0)' }

    assert_response :success
    assert_select 'header.header', count: 0
    assert_select 'nav.tabbar--navigation a[href=?]', home_path
    assert_select 'nav.tabbar--navigation a[href=?]', daylog_path
    assert_select 'nav.tabbar--navigation a[href=?]', pinned_index_path
  end

  test 'daylog opens on the newest page in chronological order' do
    total = Bullet::Pageable::PAGE_SIZE + 2
    bullets = Array.new(total) do |index|
      create_bullet!(@user, bulletable: Note.new(body: "Line #{index}"), created_at: (total - index).minutes.ago)
    end
    container = ActionView::RecordIdentifier.dom_id(@user.daylog, :bullets_container)

    get daylog_path

    assert_response :success
    assert_no_match(/Line 0\b/, response.body)
    assert_no_match(/Line 1\b/, response.body)
    assert_select "##{container} .bullet", Bullet::Pageable::PAGE_SIZE
    assert_operator response.body.index('Line 2'), :<, response.body.index("Line #{total - 1}")
    assert_select "##{container} > ##{ActionView::RecordIdentifier.dom_id(bullets[2])}:first-child"
    assert_select '.daylog--older-trigger'
  end

  test 'daylog offers the older page trigger only when a full page came back' do
    create_bullet!(@user, bulletable: Note.new(body: 'Lonely line'))

    get daylog_path

    assert_response :success
    assert_select '.daylog--older-trigger', count: 0
  end

  test 'daylog mounts the chat scroller pointed at the cursor endpoint' do
    container = ActionView::RecordIdentifier.dom_id(@user.daylog, :bullets_container)

    get daylog_path

    assert_response :success
    assert_select "[data-controller~='daylog-scroll'][data-daylog-scroll-url-value=?]", daylog_bullets_path do
      assert_select "[data-daylog-scroll-target='scroller'] ##{container}[data-daylog-scroll-target='list']"
      assert_select '#bullet_composer', count: 0
    end
    assert_select '.daylog--chat > #bullet_composer'
  end

  test 'daylog renders mixed bullet types on the same page' do
    selected_date = Date.current
    create_bullet!(@user, bulletable: Task.new(body: 'Task line'), pops_on: selected_date)
    create_bullet!(@user, bulletable: Note.new(body: 'Note line'), pops_on: selected_date)
    create_bullet!(@user, bulletable: Event.new(body: 'Event line'), pops_on: selected_date)

    get daylog_path(date: selected_date.iso8601)

    assert_response :success
    assert_match 'Task line', response.body
    assert_match 'Note line', response.body
    assert_match 'Event line', response.body
  end
end
