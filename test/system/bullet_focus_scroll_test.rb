# frozen_string_literal: true

require 'application_system_test_case'

class BulletFocusScrollSystemTest < ApplicationSystemTestCase
  PAGE = Bullet::Pageable::PAGE_SIZE

  # The show page's header sits above the scrollport, so "centered" lands a
  # little above the true viewport middle. 80px still separates a centered row
  # from an unscrolled one (which measured ~490px off).
  CENTER_TOLERANCE = 80

  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test 'the focal bullet opens centered in the scroller' do
    bullets = create_lines(70)
    focal = bullets[35]

    visit bullet_path(focal)

    assert_selector '#timeline .bullet', count: 70
    assert_within 'the focal bullet sits near the middle of the viewport', CENTER_TOLERANCE do
      focal_offset_from_viewport_center
    end
  end

  test 'a busy day still opens on its focal bullet' do
    focal = create_bullet!(@user, body: 'Focal', pops_on: Date.current - 3)
    60.times { |index| create_bullet!(@user, body: "Bulk #{index}", pops_on: Date.current - 3) }

    visit bullet_path(focal)

    assert_selector '#timeline .bullet', count: 61
    assert_within 'the focal bullet sits near the middle of the viewport', CENTER_TOLERANCE do
      focal_offset_from_viewport_center
    end
  end

  test 'a bullet near the start of the feed still opens in view' do
    bullets = create_lines(70)
    focal = bullets[2]

    visit bullet_path(focal)

    assert_selector "#bullet_#{focal.id}"
    assert_operator focal_offset_from_viewport_center, :<, viewport_height
  end

  test 'the focal bullet is highlighted and its neighbours are dimmed' do
    bullets = create_lines(30)
    focal = bullets[15]

    visit bullet_path(focal)

    assert_selector ".bullet--current[aria-current=true] #bullet_#{focal.id}"
    assert_selector "#bullet_#{bullets[0].id}:not(.bullet--current)"
    assert_ne focal_opacity, neighbour_opacity(bullets[0]),
              'expected the focal bullet to stand out from its neighbours'
  end

  private

  def assert_ne(actual, expected, message)
    refute_equal expected, actual, message
  end

  def create_lines(count)
    Array.new(count) do |index|
      create_bullet!(@user, body: "Line #{index}", created_at: (count - index).minutes.ago)
    end
  end

  def viewport_height
    page.evaluate_script('window.innerHeight')
  end

  # Positive when the focal row sits below the middle of the viewport.
  def focal_offset_from_viewport_center
    page.evaluate_script(<<~JS)
      (() => {
        const row = document.querySelector('.timeline--scroller .bullet--current')
        if (!row) return Number.NaN
        const box = row.getBoundingClientRect()
        return (box.top + box.height / 2) - window.innerHeight / 2
      })()
    JS
  end

  def focal_opacity
    opacity_of('.timeline--scroller .bullet--current')
  end

  def neighbour_opacity(bullet)
    opacity_of("#bullet_#{bullet.id}")
  end

  def opacity_of(selector)
    page.evaluate_script(
      "getComputedStyle(document.querySelector('#{selector}')).opacity"
    ).to_f
  end

  def assert_within(message, tolerance)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time
    offset = focal_offset_from_viewport_center

    while offset.abs > tolerance && Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
      sleep 0.05
      offset = focal_offset_from_viewport_center
    end

    assert_operator offset.abs, :<=, tolerance, "#{message} (offset was #{offset})"
  end
end
