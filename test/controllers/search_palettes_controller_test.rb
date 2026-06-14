# frozen_string_literal: true

require "test_helper"

class SearchPalettesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "show returns turbo stream update for menu palette" do
    @user.bullets.create!(bulletable: Task.create!, content: "Buy milk today")

    get search_palette_path(format: :turbo_stream), params: { q: "milk" }

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_match 'turbo-stream action="update" target="menu_palette_results"', response.body
    assert_match "Buy milk today", response.body
  end

  test "show caps buckets and bullets" do
    6.times { |i| create_project!(@user, name: "project #{i}") }
    9.times { |i| @user.bullets.create!(bulletable: Task.create!, content: "task item #{i}") }

    get search_palette_path(format: :turbo_stream), params: { q: "project" }

    assert_response :success
    assert_select "turbo-stream[action=?][target=?]", "update", "menu_palette_results" do
      assert_select "li.layout--list-item", maximum: 5
    end

    get search_palette_path(format: :turbo_stream), params: { q: "task" }

    assert_response :success
    assert_select "turbo-stream[action=?][target=?]", "update", "menu_palette_results" do
      assert_select "li.layout--list-item", maximum: 8
    end
  end

  test "show includes view all link when results overflow" do
    6.times { |i| create_project!(@user, name: "overflow #{i}") }

    get search_palette_path(format: :turbo_stream), params: { q: "overflow" }

    assert_response :success
    assert_match "View all results", response.body
    assert_match search_path(q: "overflow"), response.body
  end

  test "show palette bullet links to bullet show page" do
    bullet = @user.bullets.create!(bulletable: Task.create!, content: "Palette bullet")

    get search_palette_path(format: :turbo_stream), params: { q: "Palette" }

    assert_response :success
    assert_match bullet_path(bullet), response.body
    assert_select "[data-combobox-target=?]", "item"
  end

  test "show lists collections when query is blank" do
    create_collection!(@user, name: "reading list")

    get search_palette_path(format: :turbo_stream)

    assert_response :success
    assert_match "reading list", response.body
    assert_match "Collections", response.body
  end

  test "show filters collection buckets by name" do
    create_collection!(@user, name: "reading list")

    get search_palette_path(format: :turbo_stream), params: { q: "read" }

    assert_response :success
    assert_match "reading list", response.body
  end
end
