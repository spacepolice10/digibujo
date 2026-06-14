class MonthlyBucketTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "current? when period_from is this month" do
    monthly_bucket = create_monthly_bucket!(@user, name: "june")

    assert monthly_bucket.current?
  end

  test "current returns monthly bucket for this month" do
    monthly_bucket = create_monthly_bucket!(@user, name: "june")

    assert_equal monthly_bucket, MonthlyBucket.current(@user)
  end

  test "current returns nil when no spread covers this month" do
    period = MonthlyBucket.default_period
    monthly_bucket = MonthlyBucket.create!(
      user: @user,
      period_from: period[:period_from].prev_month,
      period_to: period[:period_to].prev_month.end_of_month
    )
    @user.buckets.create!(
      bucketable: monthly_bucket,
      name: "last month"
    )

    assert_nil MonthlyBucket.current(@user)
  end
end
