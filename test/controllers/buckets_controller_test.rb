# frozen_string_literal: true

require 'test_helper'

class BucketsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test 'index returns success' do
    get buckets_path
    assert_response :success
  end

  test 'index lists projects collections and monthly buckets' do
    create_project!(@user, name: 'alpha')
    create_collection!(@user, name: 'reading')
    create_monthly_bucket!(@user, name: 'june')

    get buckets_path

    assert_response :success
    assert_select 'h2.project', text: 'Projects'
    assert_select 'h2.collection', text: 'Collections'
    assert_select 'h2.monthly-bucket', text: 'Monthly spreads'
    assert_match 'alpha', response.body
    assert_match 'reading', response.body
    assert_match 'june', response.body
  end

  test 'show loads bucket bullets for footer popover' do
    collection = create_collection!(@user, name: 'bucket list')
    @user.bullets.create!(
      bulletable: Task.create!,
      body: 'In bucket',
      bucket: collection.bucket,
      pops_on: Date.current
    )

    get bucket_path(collection.bucket), headers: { 'Turbo-Frame' => dom_id(collection.bucket, :footer_bullets) }
    assert_select "turbo-frame##{dom_id(collection.bucket, :footer_bullets)}[popover].pinned--list" do
      assert_select '.dropdown--header h2', text: 'bucket list'
      assert_select '.bullet', text: /In bucket/, count: 1
    end
  end

  test 'show returns not found for another users bucket' do
    other_user = users(:two)
    collection = create_collection!(other_user, name: 'private')

    get bucket_path(collection.bucket), headers: { 'Turbo-Frame' => dom_id(collection.bucket, :footer_bullets) }
    assert_response :not_found
  end
end
