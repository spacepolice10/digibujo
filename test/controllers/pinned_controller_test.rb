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

  test "footer renders pinned bullets shell without preloading bullets" do
    @user.bullets.create!(
      bulletable: Task.create!,
      content: "Pinned bullet",
      pinned: true
    )

    get daylog_path
    assert_select "#pinned_bullets_dock .pinned--dock" do
      assert_select "button[popovertarget='pinned_bullets']", text: "Pinned"
      assert_select "turbo-frame#pinned_bullets[popover].pinned--list[src][loading='lazy']"
      assert_select ".bullet", count: 0
    end
  end

  test "pinned bullets popover loads bullets on request" do
    @user.bullets.create!(
      bulletable: Task.create!,
      content: "Pinned bullet",
      pinned: true
    )

    get pinned_index_path, headers: { "Turbo-Frame" => "pinned_bullets" }
    assert_select "turbo-frame#pinned_bullets[popover].pinned--list" do
      assert_select ".dropdown--header h2", text: "Pinned bullets"
      assert_select "button[popovertarget='pinned_bullets'][popovertargetaction='hide'][aria-label='Close pinned bullets']"
      assert_select ".bullet", text: /Pinned bullet/, count: 1
    end
  end

  test "footer renders dock per pinned bucket without preloading bullets" do
    project = create_project!(@user, name: "footer project")
    project.bucket.update!(pinned: true)

    get daylog_path
    assert_select "#pinned_buckets_footer .pinned--dock" do
      assert_select "button[popovertarget='#{dom_id(project.bucket, :footer_bullets)}']", text: /footer project/
      assert_select "turbo-frame##{dom_id(project.bucket, :footer_bullets)}[popover][src='#{bucket_path(project.bucket)}'][loading='lazy']"
      assert_select ".bullet", count: 0
    end
  end
end
