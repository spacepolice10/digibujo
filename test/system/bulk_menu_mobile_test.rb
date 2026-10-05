# frozen_string_literal: true

require 'application_system_test_case'

class BulkMenuMobileSystemTest < ApplicationSystemTestCase
  MOBILE_UA = 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 ' \
              '(KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36'

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

  test 'on mobile the open menu overlays without moving the page' do
    visit bullets_path

    before = page.evaluate_script(<<~JS)
      (() => {
        const main = document.querySelector('body > main').getBoundingClientRect()
        const tabbar = document.querySelector('.tabbar--navigation')
        const composer = document.querySelector('.composer--dock')
        return {
          mainHeight: main.height,
          tabbarHeight: tabbar ? tabbar.getBoundingClientRect().height : null,
          composerHeight: composer ? composer.getBoundingClientRect().height : null
        }
      })()
    JS

    page.execute_script("document.querySelector('[data-bulk-menu-target=checkbox]').click()")
    assert_selector '.bulk-menu'

    after = page.evaluate_script(<<~JS)
      (() => {
        const main = document.querySelector('body > main').getBoundingClientRect()
        const menu = document.querySelector('.bulk-menu').getBoundingClientRect()
        const tabbar = document.querySelector('.tabbar--navigation')
        const composer = document.querySelector('.composer--dock')
        return {
          mainHeight: main.height,
          mainBottom: main.bottom,
          menuTop: menu.top,
          tabbarHeight: tabbar ? tabbar.getBoundingClientRect().height : null,
          composerHeight: composer ? composer.getBoundingClientRect().height : null
        }
      })()
    JS

    assert_in_delta before['mainHeight'], after['mainHeight'], 1
    assert_in_delta before['tabbarHeight'], after['tabbarHeight'], 1
    assert_in_delta before['composerHeight'], after['composerHeight'], 1
    assert_operator after['menuTop'], :<, after['mainBottom']
  end
end

class BulkMenuDesktopSystemTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    sign_in_as(@user)
    create_bullet!(@user, body: 'Selectable line', created_at: Time.current)
  end

  test 'on desktop the menu overlays the page without shrinking it' do
    visit bullets_path

    before_height = page.evaluate_script(
      "document.querySelector('body > main').getBoundingClientRect().height"
    )

    page.execute_script("document.querySelector('[data-bulk-menu-target=checkbox]').click()")
    assert_selector '.bulk-menu'

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const main = document.querySelector('body > main').getBoundingClientRect()
        const menu = document.querySelector('.bulk-menu').getBoundingClientRect()
        return {
          mainHeight: main.height,
          mainBottom: main.bottom,
          menuTop: menu.top
        }
      })()
    JS

    assert_in_delta before_height, metrics['mainHeight'], 1
    assert_operator metrics['menuTop'], :<, metrics['mainBottom']
  end
end
