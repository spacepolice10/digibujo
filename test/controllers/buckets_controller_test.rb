# frozen_string_literal: true

require 'test_helper'

class BucketsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test 'show redirects to bucketable' do
    collection = create_collection!(@user, name: 'bucket list')
    create_bullet!(@user,
      bulletable: Task.new(body: 'In bucket'),
      bucket: collection.bucket,
      pops_on: nil
    )

    get bucket_path(collection.bucket)

    assert_redirected_to collection_path(collection)
  end

  test 'show returns not found for another users bucket' do
    other_user = users(:two)
    collection = create_collection!(other_user, name: 'private')

    get bucket_path(collection.bucket), headers: { 'Turbo-Frame' => dom_id(collection.bucket, :footer_bullets) }
    assert_response :not_found
  end
end
