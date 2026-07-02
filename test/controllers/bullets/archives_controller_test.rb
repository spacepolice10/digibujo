# frozen_string_literal: true

require 'test_helper'

module Bullets
  class ArchivesControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      sign_in_as @user
      @bullet = @user.bullets.create!(bulletable: Task.new(body: 'Archive me'))
    end

    test 'create archives bullet via collection path' do
      post archive_path, params: { bullet_ids: @bullet.id.to_s }

      assert_redirected_to daylog_path(date: Date.current.iso8601)
      assert @bullet.reload.archived?
    end

    test 'create archives multiple bullets in one transaction' do
      other = @user.bullets.create!(bulletable: Note.new(body: 'Also'))
      post archive_path, params: { bullet_ids: "#{@bullet.id},#{other.id}" }

      assert_redirected_to daylog_path(date: Date.current.iso8601)
      assert @bullet.reload.archived?
      assert other.reload.archived?
    end

    test 'destroy unarchives bullet' do
      @bullet.archive!
      delete archive_path, params: { bullet_ids: @bullet.id.to_s }

      assert_redirected_to daylog_path(date: Date.current.iso8601)
      assert_not @bullet.reload.archived?
    end

    test 'create returns not found for foreign bullet id' do
      foreign = users(:two).bullets.create!(bulletable: Task.new(body: 'Nope'))

      post archive_path, params: { bullet_ids: foreign.id.to_s }

      assert_response :not_found
      assert_not @bullet.reload.archived?
    end

    test 'create returns not found when more than max bulk ids' do
      ids = (1..201).to_a.join(',')

      post archive_path, params: { bullet_ids: ids }

      assert_response :not_found
    end

    test 'create removes bullets via turbo stream' do
      post archive_path,
           params: { bullet_ids: @bullet.id.to_s },
           headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      assert_response :success
      assert_match 'turbo-stream', response.media_type
      assert @bullet.reload.archived?
    end
  end
end
