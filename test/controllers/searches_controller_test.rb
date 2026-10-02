# frozen_string_literal: true

require "test_helper"

class SearchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "show renders the hub" do
    get search_path

    assert_response :success
    assert_select "main > h1", text: "Search"
    assert_select "ul[data-layout=grid]"
    assert_select "input#index-query", count: 0
    assert_select "turbo-frame#index_results", count: 0
  end

  test "show with a query still loads ranked entries for the backend" do
    matching = create_bullet!(@user, body: "Buy milk today")
    create_bullet!(@user, body: "Call mom tonight")

    get search_path, params: { q: "milk" }

    assert_response :success
    controller = @controller
    assert_equal "milk", controller.instance_variable_get(:@q)
    assert_includes controller.instance_variable_get(:@entries).map(&:id), matching.id
  end

  test "show caps query results at ten" do
    12.times { |i| create_collection!(@user, name: "indexed collection #{i}") }

    get search_path, params: { q: "indexed collection" }

    assert_response :success
    assert_equal 10, @controller.instance_variable_get(:@entries).size
  end

  test "show with blank query loads recent selections" do
    collection = create_collection!(@user, name: "recent alpha")
    Search::Selection.record!(
      user: @user,
      searchable_type: "Collection",
      searchable_id: collection.id
    )

    get search_path

    assert_response :success
    selections = @controller.instance_variable_get(:@selections)
    assert_equal 1, selections.size
    assert_equal collection, selections.first.searchable
  end

  test "mobile search keeps the three item tabbar" do
    get search_path, headers: { "User-Agent" => "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)" }

    assert_response :success
    assert_select "nav.tabbar--back", count: 0
    assert_select "nav.tabbar--navigation a.tabbar--item", count: 3
    assert_select "nav.tabbar--navigation a.tabbar--item-active[href=?]", search_path
  end

  test "desktop search page shows the three item tabbar" do
    get search_path

    assert_select "nav.tabbar--navigation a.tabbar--item", count: 3
    assert_select "nav.tabbar--navigation a.tabbar--item-active[href=?]", search_path
  end
end
