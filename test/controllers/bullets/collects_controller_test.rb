# frozen_string_literal: true

require 'test_helper'

module Bullets
  class CollectsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      sign_in_as @user
    end

    test 'create redirects to daylog and collects into collection' do
      collection = create_collection!(@user, name: 'Ideas')
      card = @user.bullets.create!(bulletable: Task.create!, body: 'Move me')

      post collect_path, params: { bullet_ids: card.id.to_s, bucket_id: collection.bucket.id }

      assert_redirected_to daylog_path(date: Date.current.iso8601)
      assert_equal collection.bucket.id, card.reload.bucket_id
      assert_empty card.projects
    end

    test 'new renders collection picker for selected bullets' do
      collection = create_collection!(@user, name: 'Ideas')
      card = @user.bullets.create!(bulletable: Task.create!, body: 'Move me')

      get new_collect_path, params: { bullet_ids: card.id.to_s }

      assert_response :success
      assert_select 'turbo-frame#collects_picker_frame'
      assert_select 'form[action=?][data-turbo-frame=?]', new_collect_path, 'collects_picker_frame'
      assert_select 'input[name="bullet_ids"][data-bulk-menu-target="idList"]'
      assert_match collection.name, response.body
      assert_match 'Collect into collection', response.body
    end

    test 'new renders picker content inside turbo frame request' do
      collection = create_collection!(@user, name: 'Ideas')
      card = @user.bullets.create!(bulletable: Task.create!, body: 'Move me')

      get new_collect_path,
          params: { bullet_ids: card.id.to_s },
          headers: { 'Turbo-Frame' => 'collects_picker_frame' }

      assert_response :success
      assert_select 'turbo-frame#collects_picker_frame .bulk-menu--action-header'
      assert_select 'input[name="bullet_ids"][data-bulk-menu-target="idList"]'
      assert_match collection.name, response.body
    end

    test 'new filters collections by search query' do
      create_collection!(@user, name: 'alpha')
      create_collection!(@user, name: 'beta')
      card = @user.bullets.create!(bulletable: Task.create!, body: 'Move me')

      get new_collect_path, params: { bullet_ids: card.id.to_s, q: 'alp' }

      assert_response :success
      assert_match 'alpha', response.body
      assert_no_match 'beta', response.body
    end

    test 'picker footer links to full page create collection with bullet context' do
      card = @user.bullets.create!(bulletable: Task.create!, body: 'Move me')

      get new_collect_path, params: { bullet_ids: card.id.to_s, return_to: daylog_path }

      assert_select 'a[href=?][data-turbo-frame=?]',
                    new_collection_path(bullet_ids: card.id.to_s, return_to: daylog_path),
                    '_top',
                    text: 'Create new collection'
    end

    test 'create collects bullet into selected collection' do
      card = @user.bullets.create!(bulletable: Note.create!, body: 'Solo')
      collection = create_collection!(@user, name: 'scratchpad')

      post collect_path, params: { bullet_ids: card.id.to_s, bucket_id: collection.bucket.id }

      assert_redirected_to daylog_path(date: Date.current.iso8601)
      assert_equal collection.bucket.id, card.reload.bucket_id
    end

    test 'create collects multiple bullets into one collection' do
      collection = create_collection!(@user, name: 'Batch')
      first = @user.bullets.create!(bulletable: Task.create!, body: 'One')
      second = @user.bullets.create!(bulletable: Note.create!, body: 'Two')

      post collect_path,
           params: { bullet_ids: "#{first.id},#{second.id}", bucket_id: collection.bucket.id }

      assert_redirected_to daylog_path(date: Date.current.iso8601)
      assert_equal collection.bucket.id, first.reload.bucket_id
      assert_equal collection.bucket.id, second.reload.bucket_id
    end

    test 'create turbo stream removes collected bullets' do
      collection = create_collection!(@user, name: 'Ideas')
      card = @user.bullets.create!(bulletable: Task.create!, body: 'Collect me')

      post collect_path,
           params: { bullet_ids: card.id.to_s, bucket_id: collection.bucket.id },
           headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      assert_response :success
      card.reload
      assert_equal collection.bucket.id, card.bucket_id
      assert_match %(turbo-stream action="remove" targets="#bullet_#{card.id}"), response.body
    end

    test 'destroy uncollects multiple bullets' do
      collection = create_collection!(@user, name: 'Clear')
      first = @user.bullets.create!(bulletable: Task.create!, body: 'A', bucket_id: collection.bucket.id)
      second = @user.bullets.create!(bulletable: Note.create!, body: 'B', bucket_id: collection.bucket.id)

      delete collect_path, params: { bullet_ids: "#{first.id},#{second.id}" }

      assert_redirected_to daylog_path(date: Date.current.iso8601)
      assert_nil first.reload.bucket_id
      assert_nil second.reload.bucket_id
    end

    test 'create rejects collect into archived collection' do
      collection = create_collection!(@user, name: 'Closed')
      collection.bucket.archive!
      card = @user.bullets.create!(bulletable: Task.create!, body: 'Move me')

      post collect_path, params: { bullet_ids: card.id.to_s, bucket_id: collection.bucket.id }

      assert_response :not_found
      assert_nil card.reload.bucket_id
    end
  end
end
