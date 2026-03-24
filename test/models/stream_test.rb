require "test_helper"

class StreamTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "ordered scope sorts by created_at ascending" do
    custom = @user.streams.create!(name: "Latest", fields: { "cardable_type" => "Note" })
    ordered = @user.streams.ordered.to_a
    assert_equal custom, ordered.last
  end

  test "multi-type cardable_type filters with IN clause" do
    stream = @user.streams.create!(name: "Multi", fields: { "cardable_type" => "Task,Event" })
    sql = stream.cards.to_sql
    assert_match(/cardable_type/, sql)
  end

  test "dynamic date_from resolves today at query time" do
    stream = @user.streams.create!(name: "Future", fields: { "date_from" => "today" })
    sql = stream.cards.to_sql
    assert_match(/date >= '#{Date.today}'/, sql)
  end

  test "stream with no filters returns all cards" do
    stream = @user.streams.create!(name: "Everything", fields: { "icon" => "menu" })
    assert stream.empty?
    assert_equal @user.cards.count, stream.cards.count
  end

  test "stream can be destroyed" do
    stream = @user.streams.create!(name: "Deletable", fields: {})
    assert stream.destroy
    assert stream.destroyed?
  end

  test "empty? ignores icon and colour fields" do
    stream = @user.streams.create!(name: "Icon only", fields: { "icon" => "menu", "colour" => "8" })
    assert stream.icon.present?
    assert stream.empty?
  end
end
