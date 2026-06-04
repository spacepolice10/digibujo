require "test_helper"

class SearchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "show renders search page" do
    get search_path

    assert_response :success
    assert_select "h2", text: "Search"
  end

  test "show filters bullets by query in content" do
    matching_card = @user.bullets.create!(bulletable: Task.create!, content: "Buy milk today")
    @user.bullets.create!(bulletable: Task.create!, content: "Call mom tonight")

    get search_path, params: { q: "milk" }

    assert_response :success
    assert_match matching_card.content.to_plain_text, response.body
    assert_no_match "Call mom tonight", response.body
  end

  test "show filters project buckets by name" do
    create_project!(@user, name: "alpha")
    create_project!(@user, name: "beta")

    get search_path, params: { q: "alp" }

    assert_response :success
    assert_select "h4", text: "Buckets"
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

  test "show returns buckets and bullets for the same query" do
    project = create_project!(@user, name: "groceries")
    @user.bullets.create!(bulletable: Task.create!, content: "Buy groceries")

    get search_path, params: { q: "grocer" }

    assert_response :success
    assert_select "h4", text: "Buckets"
    assert_select "h4", text: "Bullets"
    assert_match project.name, response.body
    assert_match "Buy groceries", response.body
  end

  test "show reports empty results when nothing matches" do
    create_project!(@user, name: "alpha")

    get search_path, params: { q: "zzz" }

    assert_response :success
    assert_match 'No results for "zzz"', response.body
  end

  test "show returns turbo stream update for realtime input requests" do
    @user.bullets.create!(bulletable: Task.create!, content: "Buy milk today")

    get search_path(format: :turbo_stream), params: { q: "milk" }

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_match 'turbo-stream action="update" target="search_results"', response.body
    assert_match "Buy milk today", response.body
  end

  test "show turbo stream includes matching bucket names" do
    create_project!(@user, name: "alpha")

    get search_path(format: :turbo_stream), params: { q: "alp" }

    assert_response :success
    assert_match "alpha", response.body
  end

  test "show finds bullets by link text from rich content as plain text" do
    @user.bullets.create!(bulletable: Note.create!, content: '<a href="https://example.com/docs">https://example.com/docs</a>')
    @user.bullets.create!(bulletable: Note.create!, content: "Unrelated content")

    get search_path, params: { q: "example.com/docs" }

    assert_response :success
    assert_match "example.com/docs", response.body
    assert_no_match "Unrelated content", response.body
  end
end
