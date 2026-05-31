# frozen_string_literal: true

require "test_helper"

class PinnedControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "index renders workspace on mobile (direct visit)" do
    get pinned_index_path, headers: { "User-Agent" => "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0)" }
    assert_response :success
    assert_select ".workspace"
  end

  test "index renders dock on desktop (turbo-frame request)" do
    get pinned_index_path, headers: { "Turbo-Frame" => "pinned_bullets_dock" }
    assert_response :success
    assert_select "turbo-frame#pinned_bullets_dock"
    assert_select ".workspace", count: 0
  end

  test "dock renders lazy pinned bullets list frame" do
    @user.bullets.create!(
      bulletable: Task.create!,
      content: "Pinned bullet",
      pinned: true
    )

    get pinned_index_path, headers: { "Turbo-Frame" => "pinned_bullets_dock" }
    assert_select ".pinned--dock" do
      assert_select "button[popovertarget='pinned_bullets']", text: "Pinned"
      assert_select "turbo-frame#pinned_bullets[popover].pinned--list[src][loading='lazy']"
      assert_select "details", count: 0
      assert_select ".bullet", count: 0
      assert_select ".pinned--dock-item-link", count: 0
    end
  end

  test "list frame renders pinned bullets" do
    @user.bullets.create!(
      bulletable: Task.create!,
      content: "Pinned bullet",
      pinned: true
    )

    get pinned_index_path, headers: { "Turbo-Frame" => "pinned_bullets" }
    assert_select "turbo-frame#pinned_bullets[popover].pinned--list" do
      assert_select ".pinned--list-header" do
        assert_select ".pinned--list-title", text: "Pinned bullets"
        assert_select "button[popovertarget='pinned_bullets'][popovertargetaction='hide'][aria-label='Close pinned bullets']"
      end
      assert_select ".bullet", text: /Pinned bullet/, count: 1
      assert_select ".pinned--dock-item-link", count: 0
    end
  end
end
