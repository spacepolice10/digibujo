# frozen_string_literal: true

require 'test_helper'

module Collections
  class ExportsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      sign_in_as @user
      @collection = create_collection!(@user, name: 'Reading List')
      @first = create_bullet!(@user,
        bulletable: Task.new, body: 'First bullet',
        bucket: @collection.bucket,
        pops_on: nil
      )
      @second = create_bullet!(@user,
        bulletable: Note.new, body: 'Second bullet',
        bucket: @collection.bucket,
        pops_on: nil
      )
    end

    test 'show downloads html for all active collection bullets' do
      get collection_export_path(@collection)

      assert_response :success
      assert_includes response.media_type, 'text/html'
      assert_match(/attachment; filename="digibujo-reading-list-export-\d{4}-\d{2}-\d{2}\.html"/,
                   response.headers['Content-Disposition'])
      assert_match '<!DOCTYPE html>', response.body
      assert_match 'First bullet', response.body
      assert_match 'Second bullet', response.body
      assert_match 'reading list export', response.body
    end

    test 'show orders bullets chronologically' do
      get collection_export_path(@collection)

      assert_response :success
      assert_operator response.body.index('First bullet'), :<, response.body.index('Second bullet')
    end

    test 'show marks completed tasks' do
      @first.bulletable.complete!

      get collection_export_path(@collection)

      assert_response :success
      assert_match 'export--bullet-body--completed', response.body
      assert_match 'Completed', response.body
    end

    test 'show excludes archived bullets in collection' do
      @first.archive!

      get collection_export_path(@collection)

      assert_response :success
      assert_no_match 'First bullet', response.body
      assert_match 'Second bullet', response.body
    end

    test 'show returns not found for foreign collection' do
      foreign = create_collection!(users(:two), name: 'Theirs')

      get collection_export_path(foreign)

      assert_response :not_found
    end

    test 'show returns not found for archived collection' do
      @collection.bucket.archive!

      get collection_export_path(@collection)

      assert_response :not_found
    end
  end
end
