# frozen_string_literal: true

require 'application_system_test_case'

class DaylogPhotoSystemTest < ApplicationSystemTestCase
  DEFAULT_WINDOW = [1400, 1400].freeze

  setup do
    Onboarding.new(user: users(:one)).complete
    @user = users(:one).reload
    attach_picture!(Date.current)
    sign_in_as(@user)
  end

  teardown do
    resize_window_to(*DEFAULT_WINDOW)
  end

  test 'the day photo peeks from behind the panel and flies out on click' do
    visit daylog_path

    assert_selector '.daylog--photo-card'
    assert_selector '.daylog--photo-toolbar'
    assert_selector '.daylog--picture [aria-label="Show photo"]'
    assert_no_selector '.daylog--picture [aria-label="Add photo"]'
    assert_no_selector '.daylog--picture [aria-label="View photo"]'
    assert_no_selector '.daylog--picture [aria-label="Remove photo"]'

    panel_right = rect('.daylog--shell')['right']
    collapsed = rect('.daylog--photo-card')

    assert_operator collapsed['left'], :<, panel_right,
                    'expected the collapsed card to be tucked behind the panel'
    assert_operator collapsed['right'], :>, panel_right,
                    'expected a sliver of the collapsed card to show past the panel'
    assert_operator collapsed['right'] - panel_right, :<, collapsed['width'] / 2,
                    'expected most of the collapsed card to stay behind the panel'

    click_peek

    assert_selector '.daylog--photo-card.is-expanded'
    expanded = settled_rect('.daylog--photo-card')

    assert_operator expanded['left'], :>=, panel_right - 1,
                    'expected the expanded card to clear the panel'
    assert_operator expanded['width'], :>, collapsed['width'],
                    'expected the expanded card to grow'

    find('body').send_keys(:escape)

    assert_no_selector '.daylog--photo-card.is-expanded'
  end

  test 'a narrow window parks the photo past the right edge of the viewport' do
    resize_window_to(900, 900)
    visit daylog_path

    assert_selector '.daylog--photo-card'
    parked = rect('.daylog--photo-card')
    viewport_width = page.evaluate_script('window.innerWidth')

    assert_operator parked['left'], :>=, viewport_width - 16,
                    'expected the collapsed card to sit past the right edge'
    assert_operator parked['right'], :>, viewport_width,
                    'expected the collapsed card to extend beyond the viewport'
  end

  test 'the header arrow pulls the photo in on a narrow window' do
    resize_window_to(900, 900)
    visit daylog_path

    find('.daylog--picture [aria-label="Show photo"]').click

    assert_selector '.daylog--photo-card.is-expanded'
    expanded = settled_rect('.daylog--photo-card')
    viewport_width = page.evaluate_script('window.innerWidth')

    assert_operator expanded['right'], :<=, viewport_width,
                    'expected the expanded card to rest inside the viewport'
    assert_operator expanded['left'], :<, viewport_width,
                    'expected the expanded card to be visible'
  end

  test 'clicking outside puts the photo back behind the panel' do
    visit daylog_path

    click_peek
    assert_selector '.daylog--photo-card.is-expanded'

    find('.daylog--scroller').click

    assert_no_selector '.daylog--photo-card.is-expanded'
  end

  private

  def resize_window_to(width, height)
    page.driver.browser.manage.window.resize_to(width, height)
  end

  # Only the sliver past the panel is clickable — the rest sits behind it.
  def click_peek
    width = page.evaluate_script(
      "document.querySelector('.daylog--photo-card').offsetWidth"
    )

    find('.daylog--photo-card').click(x: (width / 2) - 14, y: 0)
  end

  def rect(selector)
    page.evaluate_script(
      "document.querySelector(#{selector.to_json}).getBoundingClientRect().toJSON()"
    )
  end

  # The fly-out springs past its mark; measure once the geometry stops moving.
  def settled_rect(selector)
    previous = nil

    10.times do
      current = rect(selector)
      return current if previous && (previous['left'] - current['left']).abs < 0.5 &&
                        (previous['width'] - current['width']).abs < 0.5

      previous = current
      sleep 0.1
    end

    previous
  end

  def attach_picture!(date)
    picture = @user.daylog.pictures.new(date: date)
    picture.picture.attach(
      io: StringIO.new(mini_png),
      filename: 'day.png',
      content_type: 'image/png'
    )
    picture.save!
  end

  def mini_png
    Base64.decode64(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='
    )
  end
end
