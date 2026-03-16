require "test_helper"

class StreamTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "ordered scope returns defaults first then custom by created_at" do
    custom = @user.streams.create!(name: "Custom", fields: { "cardable_type" => "Note" })
    ordered = @user.streams.ordered.to_a

    defaults = ordered.select(&:default?)
    assert_equal [ 0, 1, 2, 3, 4 ], defaults.map(&:position)
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

  test "default stream cannot be destroyed" do
    stream = streams(:one_tasks)
    assert_not stream.destroy
    assert stream.persisted?
    assert_includes stream.errors[:base], "Default streams cannot be deleted"
  end

  test "default stream name cannot be changed" do
    stream = streams(:one_tasks)
    stream.name = "Renamed"
    assert_not stream.valid?
    assert_includes stream.errors[:name], "cannot be changed on default streams"
  end

  test "custom stream can be destroyed" do
    custom = @user.streams.create!(name: "Deletable", fields: {})
    assert custom.destroy
    assert custom.destroyed?
  end

  test "empty? ignores icon and colour fields" do
    stream = @user.streams.create!(name: "Icon only", fields: { "icon" => "menu", "colour" => "8" })
    assert stream.icon.present?
    assert stream.empty?
  end
end
