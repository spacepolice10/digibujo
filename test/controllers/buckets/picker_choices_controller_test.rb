# frozen_string_literal: true

require "test_helper"

module Buckets
  class PickerChoicesControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      sign_in_as @user
      @project = create_project!(@user, name: "ideas")
      @collection = create_collection!(@user, name: "inbox")
      @target = "composer_bucket_picker"
    end

    test "create turbo_stream replaces picker with project bucket" do
      post buckets_picker_choice_path,
           params: {
             bucket_id: @project.bucket.id,
             target: @target,
             field_name: "bullet[bucket_id]"
           },
           as: :turbo_stream

      assert_response :success
      assert_match @target, response.body
      assert_match @project.bucket.id.to_s, response.body
      assert_match "ideas", response.body
    end

    test "create turbo_stream replaces picker with collection bucket" do
      post buckets_picker_choice_path,
           params: {
             bucket_id: @collection.bucket.id,
             target: @target,
             field_name: "bullet[bucket_id]"
           },
           as: :turbo_stream

      assert_response :success
      assert_match @target, response.body
      assert_match @collection.bucket.id.to_s, response.body
      assert_match "inbox", response.body
    end

    test "create clear choice nullifies hidden field" do
      post buckets_picker_choice_path,
           params: {
             target: @target,
             field_name: "bullet[bucket_id]"
           },
           as: :turbo_stream

      assert_response :success
      assert_match 'value=""', response.body
      assert_match "Bucket", response.body
    end

    test "create requires target" do
      post buckets_picker_choice_path,
           params: { bucket_id: @project.bucket.id },
           as: :turbo_stream

      assert_response :bad_request
    end
  end
end
