# frozen_string_literal: true

require "test_helper"

class SearchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "show filters bullets by query in content" do
    matching_card = @user.bullets.create!(bulletable: Task.create!, body: "Buy milk today")
    @user.bullets.create!(bulletable: Task.create!, body: "Call mom tonight")

    get search_path, params: { q: "milk" }

    assert_response :success
    assert_select "turbo-frame#menu_search"
    assert_match matching_card.body.to_plain_text, response.body
    assert_no_match "Call mom tonight", response.body
  end

  test "show filters projects by name" do
    create_project!(@user, name: "alpha")
    create_project!(@user, name: "beta")

    get search_path, params: { q: "alp" }

    assert_response :success
    assert_select "h4", text: "Projects"
    assert_match "alpha", response.body
    assert_no_match "beta", response.body
  end

  test "show filters collection buckets by name" do
    create_collection!(@user, name: "reading list")
    create_collection!(@user, name: "inbox")

    get search_path, params: { q: "read" }

    assert_response :success
    assert_match "reading list", response.body
    assert_no_match "inbox", response.body
  end

  test "show filters people by name and email" do
    @user.people.create!(name: "alex", email: "alex@example.com")
    @user.people.create!(name: "sam", email: "sam@example.com")

    get search_path, params: { q: "alex@example.com" }

    assert_response :success
    assert_select "h4", text: "People"
    assert_match "alex", response.body
    assert_no_match "sam", response.body
  end

  test "show reports empty results when nothing matches" do
    create_project!(@user, name: "alpha")

    get search_path, params: { q: "zzz" }

    assert_response :success
    assert_match 'No results for "zzz"', response.body
  end

  test "show returns turbo stream update for menu search frame" do
    @user.bullets.create!(bulletable: Task.create!, body: "Buy milk today")

    get search_path(format: :turbo_stream), params: { q: "milk" }

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_match 'turbo-stream action="update" target="menu_search"', response.body
    assert_match "Buy milk today", response.body
  end

  test "show caps buckets and bullets in turbo stream results" do
    6.times { |i| create_project!(@user, name: "project #{i}") }
    9.times { |i| @user.bullets.create!(bulletable: Task.create!, body: "task item #{i}") }

    get search_path(format: :turbo_stream), params: { q: "project" }

    assert_response :success
    assert_select "turbo-stream[action=?][target=?]", "update", "menu_search" do
      assert_select "li.layout--list-item", maximum: 5
    end

    get search_path(format: :turbo_stream), params: { q: "task" }

    assert_response :success
    assert_select "turbo-stream[action=?][target=?]", "update", "menu_search" do
      assert_select "li.layout--list-item", maximum: 8
    end
  end

  test "show bullet links to bullet show page" do
    bullet = @user.bullets.create!(bulletable: Task.create!, body: "Menu bullet")

    get search_path(format: :turbo_stream), params: { q: "Menu" }

    assert_response :success
    assert_match bullet_path(bullet), response.body
    assert_select "[data-combobox-target=?]", "item"
  end

  test "show finds bullets by link text from rich content as plain text" do
    @user.bullets.create!(bulletable: Note.create!, body: '<a href="https://example.com/docs">https://example.com/docs</a>')
    @user.bullets.create!(bulletable: Note.create!, body: "Unrelated content")

    get search_path, params: { q: "example.com/docs" }

    assert_response :success
    assert_match "example.com/docs", response.body
    assert_no_match "Unrelated content", response.body
  end
end
