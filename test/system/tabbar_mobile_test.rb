# frozen_string_literal: true

require 'application_system_test_case'

class TabbarMobileSystemTest < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [390, 844]

  setup do
    sign_in_as(users(:one))
    page.driver.browser.execute_cdp('Emulation.setTouchEmulationEnabled', enabled: true)
    visit bullets_path
    assert page.evaluate_script("matchMedia('(pointer: coarse)').matches")
  end

  test 'the tabbar uses one bottom inset and gives its space to the focused composer' do
    before = layout_metrics
    assert_in_delta before['bottomInset'], before['tabbarGap'], 1
    assert_in_delta before['tabbarGap'] + before['tabbarHeight'], before['dockGap'], 3

    page.execute_script("document.querySelector('lexxy-editor .lexxy-editor__content').focus()")
    assert_selector '.composer--dock:focus-within'
    assert_no_selector '.tabbar--navigation', visible: true

    focused = layout_metrics
    assert_equal 'hidden', focused['visibility']
    assert_equal 'none', focused['pointerEvents']
    assert_in_delta before['bottomInset'], focused['dockGap'], 2
    assert_operator focused['tabbarTop'], :>=, focused['viewportHeight'] - 1

    page.execute_script("document.activeElement.blur()")
    assert_selector '.tabbar--navigation', visible: true
    assert_equal 'visible', layout_metrics['visibility']
  end

  test 'a larger PWA safe area moves the tabbar and composer by the same amount' do
    page.execute_script("document.documentElement.style.setProperty('--tabbar-bottom', '34px')")

    inset = layout_metrics
    assert_in_delta 34, inset['tabbarGap'], 1
    assert_in_delta inset['tabbarGap'] + inset['tabbarHeight'], inset['dockGap'], 3

    page.execute_script("document.querySelector('lexxy-editor .lexxy-editor__content').focus()")
    assert_selector '.composer--dock:focus-within'
    assert_no_selector '.tabbar--navigation', visible: true

    focused = layout_metrics
    assert_equal 'hidden', focused['visibility']
    assert_in_delta 34, focused['dockGap'], 1
  end

  test 'ordinary pages keep a small scroll buffer above the floating tabbar' do
    visit user_path
    assert_selector 'body > main'

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const tabbar = document.querySelector('.tabbar--navigation').getBoundingClientRect()
        const main = document.querySelector('body > main')
        return {
          padding: parseFloat(getComputedStyle(main).paddingBottom),
          clearance: innerHeight - tabbar.top
        }
      })()
    JS

    assert_operator metrics['padding'], :>, metrics['clearance']
    assert_operator metrics['padding'] - metrics['clearance'], :<, 25

    visit collections_path
    assert_selector '.tabbar--navigation.tabbar--back'
    back = page.evaluate_script(<<~JS)
      (() => {
        const tabbar = document.querySelector('.tabbar--navigation')
        return {
          gap: innerHeight - tabbar.getBoundingClientRect().bottom,
          inset: parseFloat(getComputedStyle(tabbar).bottom)
        }
      })()
    JS
    assert_in_delta back['inset'], back['gap'], 1
  end

  private

  def layout_metrics
    page.evaluate_script(<<~JS)
      (() => {
        const tabbar = document.querySelector('.tabbar--navigation')
        const dock = document.querySelector('.composer--dock')
        const rect = tabbar.getBoundingClientRect()
        const style = getComputedStyle(tabbar)
        return {
          bottomInset: parseFloat(style.bottom),
          tabbarGap: innerHeight - rect.bottom,
          tabbarTop: rect.top,
          tabbarHeight: rect.height,
          viewportHeight: innerHeight,
          dockGap: parseFloat(getComputedStyle(dock).marginBottom),
          visibility: style.visibility,
          pointerEvents: style.pointerEvents
        }
      })()
    JS
  end
end
