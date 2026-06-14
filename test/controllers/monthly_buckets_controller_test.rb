class MonthlyBucketsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "monthly bucket shows empty when no spread covers current month" do
    get monthly_bucket_path

    assert_response :success
    assert_match "No monthly spread covers", response.body
  end

  test "monthly bucket shows spread when current exists" do
    monthly_bucket = create_monthly_bucket!(@user, name: "june")
    @user.bullets.create!(
      bulletable: Task.create!,
      content: "Unplanned task",
      bucket_id: monthly_bucket.bucket.id
    )

    get monthly_bucket_path

    assert_response :success
    assert_match "Unplanned task", response.body
    assert_match "Unplanned", response.body
  end

  test "show by id lists dated bullets in by_date column" do
    monthly_bucket = create_monthly_bucket!(@user, name: "june")
    day = Date.current.beginning_of_month + 2.days
    @user.bullets.create!(
      bulletable: Event.create!,
      content: "Dentist",
      bucket_id: monthly_bucket.bucket.id,
      pops_on: day
    )

    get monthly_bucket_path(monthly_bucket)

    assert_response :success
    assert_match "Dentist", response.body
  end

  test "create duplicate month returns unprocessable entity" do
    create_monthly_bucket!(@user, name: "june")
    period = MonthlyBucket.default_period

    assert_no_difference "MonthlyBucket.count" do
      post monthly_buckets_path, params: {
        monthly_bucket: {
          name: "june again",
          period_from: period[:period_from].iso8601,
          period_to: period[:period_to].iso8601
        }
      }
    end

    assert_response :unprocessable_entity
    assert_match "already exists", response.body
  end

  test "monthly bucket scopes bulk menu controls to the spread list" do
    monthly_bucket = create_monthly_bucket!(@user, name: "june")
    @user.bullets.create!(
      bulletable: Task.create!,
      content: "Selectable compact",
      bucket_id: monthly_bucket.bucket.id
    )

    get monthly_bucket_path(monthly_bucket)

    assert_response :success
    assert_select ".monthly-bucket--spread[data-bulk-menu-target=?]", "list"
    assert_select ".bulk-menu[data-bulk-menu-target=?]", "menu"
    assert_select "input[type=checkbox][data-bulk-menu-target=?]", "checkbox"
  end

  test "monthly bucket bullets render as single-line rows without metadata tags" do
    monthly_bucket = create_monthly_bucket!(@user, name: "june")
    bullet = @user.bullets.create!(
      bulletable: Task.create!,
      content: "Pinned spread task",
      bucket_id: monthly_bucket.bucket.id
    )
    PinnedEntity.create!(user: @user, pinnable: bullet)

    get monthly_bucket_path(monthly_bucket)

    assert_response :success
    assert_select ".bullet--monthly-bucket .bullet--line", text: "Pinned spread task"
    assert_select ".bullet--monthly-bucket .bullet--tags", count: 0
    assert_select ".bullet--monthly-bucket .bullet--metadata", count: 0
  end

  test "new form defaults to current month period" do
    get new_monthly_bucket_path

    assert_response :success
    assert_select "input[name='monthly_bucket[period_from]'][value=?]", Date.current.beginning_of_month.iso8601
    assert_select "input[name='monthly_bucket[period_to]'][value=?]", Date.current.end_of_month.iso8601
  end
end
