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
    assert_select "nav a[data-hotkey=?]", "Shift+1"
    assert_select "nav a[data-hotkey=?]", "Shift+5"
    assert_select "nav a[data-controller=?]", "hotkey", count: 5
    assert_select "nav a[href=?][data-hotkey-bindings=?]", daylog_path, "Shift+2 Ctrl+D Meta+D"
    assert_select "nav a[href=?]", monthly_bucket_path
    assert_select ".menu--search[data-controller~=?]", "combobox"
    assert_select "form.search--form[action=?]", search_palette_path
    assert_select "input.search--textform[data-search-target=?]", "textform"
    assert_select "turbo-frame#menu_palette_results"
  end

  test "show lists collections in menu palette" do
    create_collection!(@user, name: "reading list")

    get menu_path

    assert_response :success
    assert_select "turbo-frame#menu_palette_results h4.search--section-heading", text: "Collections"
    assert_match "reading list", response.body
  end

  test "show renders menu page on desktop" do
    get menu_path

    assert_response :success
    assert_select "nav[data-controller=?]", "grid-navigation"
    assert_select "form.search--form[action=?]", search_palette_path
  end

  test "show pre-fills search field from q param" do
    get menu_path, params: { q: "hello" }

    assert_response :success
    assert_select "input.search--textform[value=?]", "hello"
  end
end
