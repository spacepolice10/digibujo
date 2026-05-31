# frozen_string_literal: true

require "test_helper"

module Buckets
  class PickersControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      sign_in_as @user
      @project = create_project!(@user, name: "alpha")
      @collection = create_collection!(@user, name: "reading")
      @target = "bullet_form_bucket_picker"
    end

    test "show renders modal turbo-frame for field intent" do
      get buckets_picker_path(intent: "field", target: @target),
          headers: { "Turbo-Frame" => "modal" }

      assert_response :success
      assert_select "turbo-frame#modal"
      assert_select "input[name=q]"
      assert_select ".bucket-picker-page--row-name", text: "alpha"
      assert_select ".bucket-picker-page--row-name", text: "reading"
    end

    test "show filters buckets by query" do
      get buckets_picker_path(intent: "field", target: @target, q: "read"),
          headers: { "Turbo-Frame" => "modal" }

      assert_response :success
      assert_select ".bucket-picker-page--row-name", text: "reading"
      assert_select ".bucket-picker-page--row-name", text: "alpha", count: 0
    end

    test "show requires target for field intent" do
      get buckets_picker_path(intent: "field"),
          headers: { "Turbo-Frame" => "modal" }

      assert_response :bad_request
    end

    test "show requires bullet_ids for collect intent" do
      get buckets_picker_path(intent: "collect"),
          headers: { "Turbo-Frame" => "modal" }

      assert_response :bad_request
    end

    test "show rejects invalid intent" do
      get buckets_picker_path(intent: "invalid", target: @target),
          headers: { "Turbo-Frame" => "modal" }

      assert_response :bad_request
    end

    test "list_only renders bucket list frame for inline composer" do
      panel_id = "bullet_bucket_picker_panel"
      get buckets_picker_path(intent: "field", target: @target, list_only: 1, frame_id: panel_id),
          headers: { "Turbo-Frame" => panel_id }

      assert_response :success
      assert_select "turbo-frame##{panel_id}"
      assert_select ".bucket-picker--row-name", text: "alpha"
      assert_select "input[name=q]", count: 0
    end
  end
end
