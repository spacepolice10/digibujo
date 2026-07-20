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
      card = create_bullet!(@user, bulletable: Task.new(body: 'Move me'))

      post collect_path, params: { bullet_ids: card.id.to_s, bucket_id: collection.bucket.id }

      assert_redirected_to daylog_path
      assert_equal collection.bucket.id, card.reload.bucket_id
      assert_empty card.projects
    end

    test 'new renders collection picker for selected bullets' do
      collection = create_collection!(@user, name: 'Ideas')
      card = create_bullet!(@user, bulletable: Task.new(body: 'Move me'))

      get new_collect_path, params: { bullet_ids: card.id.to_s }

      assert_response :success
      assert_select 'turbo-frame#collects_picker_dropdown_id'
      assert_select 'form[action=?]', new_collect_path
      assert_select 'input[name="bullet_ids"][data-bulk-menu-target="idList"]'
      assert_match collection.name, response.body
    end

    test 'new renders picker content inside turbo frame request' do
      collection = create_collection!(@user, name: 'Ideas')
      card = create_bullet!(@user, bulletable: Task.new(body: 'Move me'))

      get new_collect_path,
          params: { bullet_ids: card.id.to_s },
          headers: { 'Turbo-Frame' => 'collects_picker_dropdown_id' }

      assert_response :success
      assert_select 'turbo-frame#collects_picker_dropdown_id .bulk-menu--action-header'
      assert_select 'input[name="bullet_ids"][data-bulk-menu-target="idList"]'
      assert_match collection.name, response.body
    end

    test 'new filters collections by search query' do
      create_collection!(@user, name: 'alpha')
      create_collection!(@user, name: 'beta')
      card = create_bullet!(@user, bulletable: Task.new(body: 'Move me'))

      get new_collect_path, params: { bullet_ids: card.id.to_s, q: 'alp' }

      assert_response :success
      assert_match 'alpha', response.body
      assert_no_match 'beta', response.body
    end

    test 'new renders paginated collections list' do
      create_collection!(@user, name: 'Ideas')
      card = create_bullet!(@user, bulletable: Task.new(body: 'Move me'))

      get new_collect_path, params: { bullet_ids: card.id.to_s }

      assert_select '#paginated-collects-collections[data-controller="pagination"]'
    end

    test 'new turbo stream replaces list containers for live search' do
      create_collection!(@user, name: 'alpha')
      create_collection!(@user, name: 'beta')
      card = create_bullet!(@user, bulletable: Task.new(body: 'Move me'))

      get new_collect_path,
          params: { bullet_ids: card.id.to_s, q: 'alp' },
          headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      assert_response :success
      assert_match %(turbo-stream action="replace" target="paginated-collects-collections"), response.body
      assert_match 'alpha', response.body
      assert_no_match 'beta', response.body
    end

    test 'picker heading links to full page create collection with bullet context' do
      card = create_bullet!(@user, bulletable: Task.new(body: 'Move me'))

      get new_collect_path, params: { bullet_ids: card.id.to_s, return_to: daylog_path }

      assert_select 'a[href=?][data-turbo-frame=?][aria-label=?]',
                    new_collection_path(bullet_ids: card.id.to_s, return_to: daylog_path),
                    '_top',
                    'Create new collection'
    end

    test 'create collects bullet into selected collection' do
      card = create_bullet!(@user, bulletable: Note.new(body: 'Solo'))
      collection = create_collection!(@user, name: 'scratchpad')

      post collect_path, params: { bullet_ids: card.id.to_s, bucket_id: collection.bucket.id }

      assert_redirected_to daylog_path
      assert_equal collection.bucket.id, card.reload.bucket_id
    end

    test 'create collects multiple bullets into one collection' do
      collection = create_collection!(@user, name: 'Batch')
      first = create_bullet!(@user, bulletable: Task.new(body: 'One'))
      second = create_bullet!(@user, bulletable: Note.new(body: 'Two'))

      post collect_path,
           params: { bullet_ids: "#{first.id},#{second.id}", bucket_id: collection.bucket.id }

      assert_redirected_to daylog_path
      assert_equal collection.bucket.id, first.reload.bucket_id
      assert_equal collection.bucket.id, second.reload.bucket_id
    end

    test 'create turbo stream removes collected bullets' do
      collection = create_collection!(@user, name: 'Ideas')
      card = create_bullet!(@user, bulletable: Task.new(body: 'Collect me'))

      post collect_path,
           params: { bullet_ids: card.id.to_s, bucket_id: collection.bucket.id },
           headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      assert_response :success
      card.reload
      assert_equal collection.bucket.id, card.bucket_id
      assert_match %(turbo-stream action="remove" targets="#bullet_#{card.id}"), response.body
      assert_match %(turbo-stream action="update" target="toasts"), response.body
      assert_match "Bullet collected into #{collection.name}", response.body
    end

    test 'create rejects collect into archived collection' do
      collection = create_collection!(@user, name: 'Closed')
      collection.bucket.archive!
      card = create_bullet!(@user, bulletable: Task.new(body: 'Move me'))
      daylog_bucket_id = card.bucket_id

      post collect_path, params: { bullet_ids: card.id.to_s, bucket_id: collection.bucket.id }

      assert_response :not_found
      assert_equal daylog_bucket_id, card.reload.bucket_id
    end
  end
end
