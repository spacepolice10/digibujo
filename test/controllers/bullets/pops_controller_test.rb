# frozen_string_literal: true

require "test_helper"

class Bullets::PopsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "new renders pop picker for selected bullets" do
    card = @user.bullets.create!(bulletable: Task.create!, content: "Schedule me")

    get new_pop_path, params: { bullet_ids: card.id.to_s }

    assert_response :success
    assert_select "turbo-frame#pops_picker_frame"
    assert_select 'input[name="bullet_ids"][data-bulk-menu-target="idList"]', count: 4
    assert_select "input[type=date][name=pops_on]"
    assert_match "ASAP", response.body
    assert_match "Tomorrow", response.body
    assert_match "Next week", response.body
    assert_match Date.current.next_occurring(:monday).strftime("%a, %b %-d"), response.body
  end

  test "new renders picker content inside turbo frame request" do
    card = @user.bullets.create!(bulletable: Task.create!, content: "Schedule me")

    get new_pop_path,
        params: { bullet_ids: card.id.to_s },
        headers: { "Turbo-Frame" => "pops_picker_frame" }

    assert_response :success
    assert_select "turbo-frame#pops_picker_frame .bulk-menu--pops-header"
    assert_select 'input[name="bullet_ids"][data-bulk-menu-target="idList"]', count: 4
  end

  test "new without bullet_ids returns not found" do
    get new_pop_path

    assert_response :not_found
  end

  test "create redirects to daylog and sets pop day" do
    card = @user.bullets.create!(bulletable: Task.create!, content: "Plan me")
    target = 3.days.from_now.to_date

    post pop_path, params: { bullet_ids: card.id.to_s, pops_on: target.iso8601 }

    assert_redirected_to daylog_path(date: Date.current.iso8601)
    assert_equal target, card.reload.pops_on
  end

  test "create ignores bucket_id" do
    collection = create_collection!(@user, name: "Deep work")
    card = @user.bullets.create!(bulletable: Event.create!, content: "Workshop")
    target = 1.week.from_now.to_date

    post pop_path,
         params: { bullet_ids: card.id.to_s, pops_on: target.iso8601, bucket_id: collection.bucket.id }

    assert_redirected_to daylog_path(date: Date.current.iso8601)
    assert_equal target, card.reload.pops_on
    assert_nil card.bucket_id
  end

  test "create with pops_on one day ahead acts as postpone from bullet pop day" do
    anchor = 5.days.from_now.to_date
    card = @user.bullets.create!(
      bulletable: Task.create!,
      content: "Defer me",
      pops_on: anchor
    )

    post pop_path, params: { bullet_ids: card.id.to_s, pops_on: (anchor + 1.day).iso8601 }

    assert_redirected_to daylog_path(date: Date.current.iso8601)
    assert_equal anchor + 1.day, card.reload.pops_on
  end

  test "create with pops_on from daylog viewing day acts as postpone from that anchor" do
    view_day = Date.current
    card = @user.bullets.create!(
      bulletable: Task.create!,
      content: "Triage",
      pops_on: 2.weeks.from_now.to_date
    )

    post pop_path, params: { bullet_ids: card.id.to_s, pops_on: (view_day + 1.day).iso8601 }

    assert_redirected_to daylog_path(date: Date.current.iso8601)
    assert_equal view_day + 1.day, card.reload.pops_on
  end

  test "create with pops_on one week ahead" do
    view_day = Date.current
    card = @user.bullets.create!(bulletable: Event.create!, content: "Later", pops_on: nil)

    post pop_path, params: { bullet_ids: card.id.to_s, pops_on: (view_day + 1.week).iso8601 }

    assert_redirected_to daylog_path(date: Date.current.iso8601)
    assert_equal view_day + 1.week, card.reload.pops_on
  end

  test "create pops multiple bullets to same day" do
    target = 4.days.from_now.to_date
    first = @user.bullets.create!(bulletable: Task.create!, content: "A")
    second = @user.bullets.create!(bulletable: Note.create!, content: "B")

    post pop_path, params: { bullet_ids: "#{first.id},#{second.id}", pops_on: target.iso8601 }

    assert_redirected_to daylog_path(date: Date.current.iso8601)
    assert_equal target, first.reload.pops_on
    assert_equal target, second.reload.pops_on
  end

  test "create turbo stream removes popped bullets and shows scheduled notice" do
    card = @user.bullets.create!(bulletable: Task.create!, content: "Plan me")
    target = 3.days.from_now.to_date

    post pop_path,
         params: { bullet_ids: card.id.to_s, pops_on: target.iso8601 },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_equal target, card.reload.pops_on
    assert_match %(turbo-stream action="update" target="toasts"), response.body
    assert_match "Bullet scheduled for #{target.strftime("%B %d")}", response.body
    assert_match %(turbo-stream action="remove" targets="#bullet_#{card.id}"), response.body
    assert_no_match "pops_notice", response.body
  end

  test "destroy clears pops_on" do
    target = 2.days.from_now.to_date
    card = @user.bullets.create!(
      bulletable: Task.create!,
      content: "Clear day",
      pops_on: target
    )

    delete pop_path, params: { bullet_ids: card.id.to_s, pops_on: "" }

    assert_redirected_to daylog_path(date: Date.current.iso8601)
    assert_nil card.reload.pops_on
  end

  test "create returns unprocessable entity for invalid pops_on" do
    card = @user.bullets.create!(bulletable: Task.create!, content: "Bad date")

    post pop_path,
         params: { bullet_ids: card.id.to_s, pops_on: "not-a-date" },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :unprocessable_entity
    assert_nil card.reload.pops_on
  end

  test "create turbo stream moves unplanned monthly bucket bullet to date row without toast" do
    monthly_bucket = create_monthly_bucket!(@user, name: "june")
    day = Date.current.beginning_of_month + 2.days
    card = @user.bullets.create!(
      bulletable: Task.create!,
      content: "Plan in spread",
      bucket_id: monthly_bucket.bucket.id
    )

    post pop_path,
         params: { bullet_ids: card.id.to_s, pops_on: day.iso8601 },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_equal day, card.reload.pops_on
    assert_equal monthly_bucket.bucket.id, card.bucket_id
    assert_match %(turbo-stream action="remove" target="#{dom_id(card)}"), response.body
    assert_match %(turbo-stream action="append" target="#{dom_id(monthly_bucket, "date_#{day}_bullets")}"), response.body
    assert_no_match %(turbo-stream action="update" target="toasts"), response.body
  end

  test "destroy turbo stream moves monthly bucket bullet to unplanned" do
    monthly_bucket = create_monthly_bucket!(@user, name: "june")
    day = Date.current.beginning_of_month + 2.days
    card = @user.bullets.create!(
      bulletable: Event.create!,
      content: "Unplan me",
      bucket_id: monthly_bucket.bucket.id,
      pops_on: day
    )

    delete pop_path,
           params: { bullet_ids: card.id.to_s, pops_on: "" },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_nil card.reload.pops_on
    assert_equal monthly_bucket.bucket.id, card.bucket_id
    assert_match %(turbo-stream action="remove" target="#{dom_id(card)}"), response.body
    assert_match %(turbo-stream action="append" target="#{dom_id(monthly_bucket, :unplanned_bullets)}"), response.body
  end
end
