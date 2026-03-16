require "test_helper"

class StreamsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "index returns streams in order" do
    get streams_path
    assert_response :success
    assert_select ".streams-type-item", count: 6 # 1 hardcoded "All Cards" + 5 defaults
  end

  test "show renders a default stream" do
    get stream_path(streams(:one_tasks))
    assert_response :success
  end

  test "destroy is forbidden for default streams" do
    assert_no_difference "Stream.count" do
      delete stream_path(streams(:one_tasks))
    end
    assert_response :forbidden
  end

  test "destroy works for custom streams" do
    custom = @user.streams.create!(name: "Temp", fields: {})
    assert_difference "Stream.count", -1 do
      delete stream_path(custom)
    end
    assert_redirected_to root_path
  end
end
