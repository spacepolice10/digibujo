require "test_helper"

class StreamsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "index returns streams" do
    get streams_path
    assert_response :success
  end

  test "destroy works for custom streams" do
    custom = @user.streams.create!(name: "Temp", fields: {})
    assert_difference "Stream.count", -1 do
      delete stream_path(custom)
    end
    assert_redirected_to root_path
  end
end
