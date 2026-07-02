# frozen_string_literal: true

require "test_helper"

class MenuControllerTest < ActionDispatch::IntegrationTest
  MOBILE_UA = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)"

  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "show redirects to home on mobile" do
    get menu_path, headers: { "User-Agent" => MOBILE_UA }

    assert_redirected_to home_path
  end

  test "show renders menu page on desktop" do
    get menu_path

    assert_response :success
    assert_select ".menu--page-mobile", count: 0
    assert_select "nav[data-controller=?]", "grid-navigation"
    assert_select "form.search--form[action=?]", search_path
    assert_select "label.form-label.utilities--sr-only[for=?]", "q", text: "Search bullets, projects, collections, and people"
    assert_select "input.form-input[placeholder=?]", "Search…"
    assert_select "turbo-frame#menu_search[src=?]", search_path
    assert_select "[data-search-replace-link-value]", count: 0
    assert_select "[data-search-history-url-value]", count: 0
  end
end
