# frozen_string_literal: true

require 'application_system_test_case'

class DaylogChatSystemTest < ApplicationSystemTestCase
  PAGE = Bullet::Pageable::PAGE_SIZE

  setup do
    Onboarding.new(user: users(:one)).complete
    @user = users(:one).reload
    sign_in_as(@user)
    @list = "##{ActionView::RecordIdentifier.dom_id(@user.daylog, :bullets_container)}"
  end

  test 'the daylog opens at the newest bullet with older ones left off screen' do
    create_lines(70)

    visit daylog_path

    assert_selector "#{@list} .bullet", count: PAGE
    assert_text 'Line 69'
    assert_no_text 'Line 0'
    assert_pinned_to_bottom
  end

  test 'scrolling to the top loads older pages without moving the read row' do
    create_lines(70)
    visit daylog_path
    assert_selector "#{@list} .bullet", count: PAGE

    # First trip to the top fills the scrollport (short pages keep the trigger
    # intersecting). Anchor preservation only applies once we already overflow.
    scroll_to_top
    wait_for_stable_bullet_count(minimum: PAGE * 2)

    assert_selector '.daylog--older-trigger'
    previous = page.all("#{@list} .bullet").size
    anchor = find("#{@list} .bullet", match: :first)[:id]
    scroll_to_top
    before = row_top(anchor)

    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time
    while page.all("#{@list} .bullet").size <= previous &&
          Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
      sleep 0.05
    end

    assert_operator page.all("#{@list} .bullet").size, :>, previous
    assert_in_delta before, row_top(anchor), 2
  end

  test 'a short day keeps bullets on the composer edge' do
    create_lines(2)
    visit daylog_path

    assert_selector "#{@list} .bullet", count: 2
    list_id = @list.delete_prefix('#')
    gap = page.evaluate_script(<<~JS)
      (() => {
        const scroller = document.querySelector('.daylog--scroller')
        const list = document.getElementById(#{list_id.to_json})
        const pad = parseFloat(getComputedStyle(scroller).paddingBottom) || 0
        return Math.abs((scroller.getBoundingClientRect().bottom - pad) - list.getBoundingClientRect().bottom)
      })()
    JS
    assert_operator gap, :<=, 2, 'expected the short list to sit on the bottom of the scroller'
  end

  test 'the older trigger disappears once the whole day is loaded' do
    create_lines(PAGE + 5)
    visit daylog_path
    assert_selector '.daylog--older-trigger'

    scroll_to_top

    assert_no_selector '.daylog--older-trigger'
    assert_selector "#{@list} .bullet", count: PAGE + 5
    assert_text 'Line 0'
  end

  test 'sending a bullet keeps the reader at the newest row' do
    create_lines(70)
    visit daylog_path

    editor = find('#bullet_composer lexxy-editor .lexxy-editor__content')
    editor.click
    editor.send_keys('Fresh line')
    editor.send_keys(:enter)

    assert_text 'Fresh line'
    assert_pinned_to_bottom
  end

  private

  def assert_pinned_to_bottom
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time
    gap = distance_from_bottom

    while gap > 2 && Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
      sleep 0.05
      gap = distance_from_bottom
    end

    assert_operator gap, :<=, 2, 'expected the daylog to rest on the newest bullet'
  end

  def wait_for_stable_bullet_count(minimum:)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time
    previous = nil
    stable_since = nil

    loop do
      current = page.all("#{@list} .bullet", visible: :all).size
      now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      if current >= minimum && current == previous
        stable_since ||= now
        return current if now - stable_since >= 0.3
      else
        stable_since = nil
      end

      break if now >= deadline

      previous = current
      sleep 0.1
    end

    flunk "bullet count did not stabilize at >= #{minimum} (last=#{previous})"
  end

  def create_lines(count)
    Array.new(count) do |index|
      create_bullet!(@user, bulletable: Note.new(body: "Line #{index}"), created_at: (count - index).minutes.ago)
    end
  end

  def scroll_to_top
    page.execute_script("document.querySelector('.daylog--scroller').scrollTop = 0")
  end

  def distance_from_bottom
    page.evaluate_script(<<~JS)
      (() => {
        const scroller = document.querySelector('.daylog--scroller')
        return scroller.scrollHeight - scroller.scrollTop - scroller.clientHeight
      })()
    JS
  end

  def row_top(id)
    page.evaluate_script("document.getElementById('#{id}').getBoundingClientRect().top")
  end
end
