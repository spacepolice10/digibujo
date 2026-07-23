# frozen_string_literal: true

require "test_helper"

class SearchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "show filters bullets by query in content" do
    matching_card = create_bullet!(@user, bulletable: Task.new(body: "Buy milk today"))
    create_bullet!(@user, bulletable: Task.new(body: "Call mom tonight"))

    get search_path, params: { q: "milk" }

    assert_response :success
    assert_select "turbo-frame#menu_search"
    assert_match matching_card.name, response.body
    assert_no_match "Call mom tonight", response.body
  end

  test "show filters projects by name" do
    create_project!(@user, name: "alpha")
    create_project!(@user, name: "beta")

    get search_path, params: { q: "alp" }

    assert_response :success
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

  test "show reports empty results when nothing matches" do
    create_project!(@user, name: "alpha")

    get search_path, params: { q: "zzz" }

    assert_response :success
    assert_match 'No results for "zzz"', response.body
  end

  test "show returns turbo stream update for menu search frame" do
    create_bullet!(@user, bulletable: Task.new(body: "Buy milk today"))

    get search_path(format: :turbo_stream), params: { q: "milk" }

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_match 'turbo-stream action="update" target="menu_search"', response.body
    assert_match "Buy milk today", response.body
  end

  test "show caps flat results at the global limit" do
    25.times { |i| create_project!(@user, name: "project #{i}") }

    get search_path(format: :turbo_stream), params: { q: "project" }

    assert_response :success
    assert_select "turbo-stream[action=?][target=?]", "update", "menu_search" do
      assert_select "li[role=option]", maximum: Search::GlobalRequest::LIMIT
    end
  end

  test "show bullet links to bullet show page" do
    bullet = create_bullet!(@user, bulletable: Task.new(body: "Menu bullet"))

    get search_path(format: :turbo_stream), params: { q: "Menu" }

    assert_response :success
    assert_match bullet_path(bullet), response.body
    assert_select "[data-combobox-target=?]", "item"
  end

  test "show finds bullets by link text from rich content as plain text" do
    create_bullet!(@user, bulletable: Note.new(body: '<a href="https://example.com/docs">https://example.com/docs</a>'))
    create_bullet!(@user, bulletable: Note.new(body: "Unrelated content"))

    get search_path, params: { q: "example.com/docs" }

    assert_response :success
    assert_match "example.com/docs", response.body
    assert_no_match "Unrelated content", response.body
  end

  test "show with blank query renders recent selections" do
    project = create_project!(@user, name: "recent alpha")
    Search::Selection.record!(
      user: @user,
      searchable_type: "Project",
      searchable_id: project.id
    )

    get search_path

    assert_response :success
    assert_turbo_frame "menu_search"
    assert_page_text "recent alpha"
  end

  test "show with blank query and no selections renders recents placeholder" do
    get search_path

    assert_response :success
    assert_select "ul[role=listbox]", count: 0
    assert_page_text "No recent searches."
  end

  test "show with query does not render recent selections" do
    project = create_project!(@user, name: "recent beta")
    Search::Selection.record!(
      user: @user,
      searchable_type: "Project",
      searchable_id: project.id
    )

    get search_path, params: { q: "recent" }

    assert_response :success
    assert_select "ul[role=listbox]", count: 1
    assert_page_text "recent beta"
  end

  test "show with blank query renders recent list on mobile" do
    project = create_project!(@user, name: "recent mobile")
    Search::Selection.record!(
      user: @user,
      searchable_type: "Project",
      searchable_id: project.id
    )

    get search_path, headers: { "User-Agent" => "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)" }

    assert_response :success
    assert_select "details summary", text: "Recent", count: 0
    assert_select "ul[role=listbox]", count: 1
    assert_page_text "recent mobile"
  end
end
