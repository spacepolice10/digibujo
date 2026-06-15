# frozen_string_literal: true

require "test_helper"

class MenuControllerTest < ActionDispatch::IntegrationTest
  MOBILE_UA = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)"

  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "show renders menu page on mobile" do
    get menu_path, headers: { "User-Agent" => MOBILE_UA }

    assert_response :success
    assert_select "nav[data-controller=?][data-grid-navigation-columns-value=?]", "grid-navigation", "1"
    assert_select "nav a.button--secondary.button--hotkey[data-grid-navigation-target=?]", "item", count: 5
    assert_select "form.search--form[action=?]", search_path
    assert_select "turbo-frame#menu_search"
  end

  test "show renders menu page on desktop" do
    get menu_path

    assert_response :success
    assert_select "nav[data-controller=?]", "grid-navigation"
    assert_select "form.search--form[action=?]", search_path
  end

  test "show pre-fills search field from q param" do
    get menu_path, params: { q: "hello" }

    assert_response :success
    assert_select "input.search--textform[value=?]", "hello"
    assert_select "turbo-frame#menu_search[src=?]", search_path(q: "hello")
  end
end
