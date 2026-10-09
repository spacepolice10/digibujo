# frozen_string_literal: true

require "application_system_test_case"

class BulkMenuFloatingCardSystemTest < ApplicationSystemTestCase
  MOBILE_UA = "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 " \
              "(KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36"

  driven_by :selenium,
            using: :headless_chrome,
            screen_size: [390, 844],
            options: { name: :selenium_mobile } do |options|
    options.add_argument("--user-agent=#{MOBILE_UA}")
    options.add_argument("--use-fake-device-for-media-stream")
    options.add_argument("--use-fake-ui-for-media-stream")
  end

  setup do
    @user = users(:one)
    sign_in_as(@user)
    create_bullet!(@user, body: "Selectable line", created_at: Time.current)
    create_bullet!(@user, body: "Second line", created_at: Time.current)
  end

  test "bulk menu opens expanded and swipes down to heading peek via scroll snap" do
    visit bullets_path
    page.execute_script("document.querySelectorAll('[data-bulk-menu-target=checkbox]')[0].click()")
    assert_selector ".bulk-menu", visible: true

    snap = page.evaluate_script(
      "getComputedStyle(document.querySelector('.bulk-menu')).scrollSnapType"
    )
    assert_includes snap, "mandatory"

    # Opening scrolls to expanded (smooth animation — wait for it to settle).
    state = nil
    start = Time.now
    loop do
      state = floating_card_state
      break if (state["max"] - state["scrollTop"]).abs <= 2
      raise "floating card never opened expanded" if Time.now - start > 5

      sleep 0.1
    end
    assert state["scrollable"], "expected floating card to be scrollable"

    # Swipe down to the heading peek.
    page.execute_script(
      "document.querySelector('.bulk-menu').scrollTo({ top: 0, behavior: 'instant' })"
    )

    peek = page.evaluate_script(
      <<~JS
        (() => {
          const header = document.querySelector('.bulk-menu--card header, .bulk-menu header').getBoundingClientRect();
          const actions = document.querySelector('.bulk-menu--actions').getBoundingClientRect();
          return {
            headerVisible: header.top < window.innerHeight && header.bottom > 0,
            actionsTop: actions.top
          };
        })()
      JS
    )
    assert peek["headerVisible"], "expected heading to stay visible in peek state"
    assert_operator peek["actionsTop"], :>=, window_height - 2,
      "expected actions to be pushed below the viewport in peek state"

    # Selecting more bullets while collapsed must not expand the floating card.
    page.execute_script("document.querySelectorAll('[data-bulk-menu-target=checkbox]')[1].click()")
    assert_selector ".bulk-menu", visible: true
    collapsed = floating_card_state
    assert_in_delta 0, collapsed["scrollTop"], 4,
      "expected selecting another bullet to keep the floating card collapsed"
    assert_text "2 selected"

    # Swipe back up to the full menu.
    page.execute_script(
      "document.querySelector('.bulk-menu').scrollTo({ top: document.querySelector('.bulk-menu').scrollHeight, behavior: 'instant' })"
    )
    assert_selector ".bulk-menu--actions", visible: true
  end

  private

  def floating_card_state
    page.evaluate_script(
      <<~JS
        (() => {
          const menu = document.querySelector('.bulk-menu');
          return {
            scrollTop: menu.scrollTop,
            max: menu.scrollHeight - menu.clientHeight,
            scrollable: menu.scrollHeight > menu.clientHeight + 1
          };
        })()
      JS
    )
  end

  def window_height
    page.evaluate_script("window.innerHeight")
  end
end
