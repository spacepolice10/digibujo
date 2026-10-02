# frozen_string_literal: true

require 'application_system_test_case'

class BulkMenuMobileSystemTest < ApplicationSystemTestCase
  MOBILE_UA = 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 ' \
              '(KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36'
  LAYOUT_SCRIPT = <<~JS
    (() => {
      const box = (el) => {
        const rect = el.getBoundingClientRect()
        return { top: rect.top, bottom: rect.bottom, height: rect.height }
      }
      const bodyStyle = getComputedStyle(document.body)
      const tabbar = document.querySelector('.tabbar--navigation')
      const composer = document.querySelector('.composer--dock')
      return {
        band: bodyStyle.getPropertyValue('--bulk-menu-band').trim(),
        footprint: bodyStyle.getPropertyValue('--bulk-menu-footprint').trim(),
        clearance: bodyStyle.getPropertyValue('--bulk-menu-clearance').trim(),
        viewport: window.innerHeight,
        main: box(document.querySelector('body > main')),
        menu: box(document.querySelector('.bulk-menu')),
        tabbar: tabbar ? box(tabbar) : null,
        composerHeight: composer ? composer.getBoundingClientRect().height : null
      }
    })()
  JS

  driven_by :selenium,
            using: :headless_chrome,
            screen_size: [390, 844],
            options: { name: :selenium_mobile } do |options|
    options.add_argument("--user-agent=#{MOBILE_UA}")
    options.add_argument('--use-fake-device-for-media-stream')
    options.add_argument('--use-fake-ui-for-media-stream')
  end

  setup do
    @user = users(:one)
    sign_in_as(@user)
    create_bullet!(@user, body: 'Selectable line', created_at: Time.current)
  end

  test 'on mobile the open menu compresses the page above it' do
    visit bullets_path

    assert_selector 'body[data-platform="mobile"]'
    page.execute_script("document.body.style.setProperty('--tabbar-motion', '1200ms linear')")
    select_first_bullet
    assert_selector '.bulk-menu', visible: :all

    mid = wait_for_midpoint
    assert_in_delta mid['main']['bottom'], mid['menu']['top'], 6
    assert_operator mid['tabbar']['height'], :>, 1
    assert_operator mid['composerHeight'], :>, 1

    metrics = wait_for_layout
    menu_top = metrics['menu']['top']

    assert_match(/\d/, metrics['band'])
    assert_operator metrics['main']['bottom'], :<=, menu_top + 4
    assert_operator metrics['tabbar']['height'], :<=, 1
    assert_operator metrics['composerHeight'], :<=, 1
    assert_operator metrics['main']['height'], :<, metrics['viewport'] - 40
  end

  private

  def select_first_bullet
    page.execute_script("document.querySelector('[data-bulk-menu-target=checkbox]').click()")
  end

  def wait_for_midpoint
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time

    while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
      metrics = measure_layout
      band = metrics['band'].to_f
      footprint = metrics['footprint'].to_f
      return metrics if band > 8 && footprint > band + 8

      sleep 0.03
    end

    flunk 'menu never passed through a mid-transition frame'
  end

  def wait_for_layout
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time
    metrics = measure_layout

    while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
      return metrics if layout_settled?(metrics)

      sleep 0.05
      metrics = measure_layout
    end

    metrics
  end

  def layout_settled?(metrics)
    metrics['main']['bottom'] <= metrics['menu']['top'] + 4 &&
      metrics['tabbar']['height'] <= 1 &&
      metrics['composerHeight'] <= 1
  end

  def measure_layout
    page.evaluate_script(LAYOUT_SCRIPT)
  end
end

class BulkMenuDesktopSystemTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    sign_in_as(@user)
    create_bullet!(@user, body: 'Selectable line', created_at: Time.current)
  end

  test 'on desktop the menu still overlays the page' do
    visit bullets_path

    assert_selector 'body[data-platform="desktop"]'
    page.execute_script("document.querySelector('[data-bulk-menu-target=checkbox]').click()")
    assert_selector '.bulk-menu'

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const bodyStyle = getComputedStyle(document.body)
        const main = document.querySelector('body > main').getBoundingClientRect()
        const menu = document.querySelector('.bulk-menu').getBoundingClientRect()
        return {
          band: bodyStyle.getPropertyValue('--bulk-menu-band').trim(),
          clearance: bodyStyle.getPropertyValue('--bulk-menu-clearance').trim(),
          mainBottom: main.bottom,
          menuTop: menu.top
        }
      })()
    JS

    assert_equal '0px', metrics['band']
    assert_operator metrics['menuTop'], :<, metrics['mainBottom']
    assert_match(/\d/, metrics['clearance'])
  end
end
