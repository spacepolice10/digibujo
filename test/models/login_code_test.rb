require "test_helper"

class LoginCodeTest < ActiveSupport::TestCase
  setup { @user = users(:one) }

  test "generate_code returns CODE_LENGTH uppercase alphanumeric string" do
    code = LoginCode.generate_code
    assert_equal LoginCode::CODE_LENGTH, code.length
    assert_match(/\A[A-Z0-9]+\z/, code)
  end

  test "create_for returns record and plaintext code" do
    record, code = LoginCode.create_for(@user)

    assert record.persisted?
    assert_equal LoginCode::CODE_LENGTH, code.length
    assert record.code_matches?(code)
  end

  test "code_matches? returns true for correct code" do
    record, code = LoginCode.create_for(@user)
    assert record.code_matches?(code)
  end

  test "code_matches? returns false for wrong code" do
    record, _code = LoginCode.create_for(@user)
    assert_not record.code_matches?("WRONG1")
  end

  test "code_matches? is case-insensitive" do
    record, code = LoginCode.create_for(@user)
    assert record.code_matches?(code.downcase)
  end

  test "expired? returns false for fresh code" do
    record, _code = LoginCode.create_for(@user)
    assert_not record.expired?
  end

  test "expired? returns true after expiry" do
    record, _code = LoginCode.create_for(@user)
    record.update!(expires_at: 1.minute.ago)
    assert record.expired?
  end

  test "sweep deletes expired codes" do
    record, _code = LoginCode.create_for(@user)
    record.update!(expires_at: 1.minute.ago)

    assert_difference "LoginCode.count", -1 do
      LoginCode.sweep
    end
  end

  test "sweep keeps active codes" do
    LoginCode.create_for(@user)

    assert_no_difference "LoginCode.count" do
      LoginCode.sweep
    end
  end

  test "before_create sets expires_at" do
    record, _code = LoginCode.create_for(@user)
    assert_in_delta LoginCode::EXPIRY.from_now, record.expires_at, 2.seconds
  end
end
