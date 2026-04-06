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

  # No mobile User-Agent → desktop layout. Turbo-Frame header is incidental here —
  # used so the frame element appears in the response for assertion.
  test "index renders dock on desktop (turbo-frame request)" do
    get pinned_index_path, headers: { "Turbo-Frame" => "pinned_panel" }
    assert_response :success
    assert_select "turbo-frame#pinned_panel"
    assert_select ".workspace", count: 0
  end
end
