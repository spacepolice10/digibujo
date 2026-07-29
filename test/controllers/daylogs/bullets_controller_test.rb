# frozen_string_literal: true

require 'test_helper'

class Daylogs::BulletsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    ensure_daylog!(@user)
  end

  test 'index returns the rows just older than the cursor' do
    bullets = create_bullets(4)

    get daylog_bullets_path(before: bullets[2].id)

    assert_response :success
    assert_select '.bullet', 2
    assert_match 'Line 0', response.body
    assert_match 'Line 1', response.body
    assert_no_match(/Line 2/, response.body)
  end

  test 'index renders rows without the page chrome' do
    bullets = create_bullets(2)

    get daylog_bullets_path(before: bullets.last.id)

    assert_response :success
    assert_select 'header.header', count: 0
    assert_select '#bullet_composer', count: 0
  end

  test 'index answers no content once there is nothing older' do
    bullets = create_bullets(2)

    get daylog_bullets_path(before: bullets.first.id)

    assert_response :no_content
  end

  test 'index answers no content for an unknown cursor' do
    get daylog_bullets_path(before: 0)

    assert_response :no_content
  end

  test 'index answers no content for another users bullet' do
    other = create_bullet!(users(:two), bulletable: Note.new(body: 'Not yours'))

    get daylog_bullets_path(before: other.id)

    assert_response :no_content
  end

  test 'index stays within the day of the cursor' do
    yesterday = Date.current - 1.day
    create_bullet!(@user, bulletable: Note.new(body: 'Yesterday line'), pops_on: yesterday,
                          created_at: 2.days.ago)
    today = create_bullets(2)

    get daylog_bullets_path(before: today.last.id)

    assert_response :success
    assert_match 'Line 0', response.body
    assert_no_match(/Yesterday line/, response.body)
  end

  test 'index skips archived bullets' do
    bullets = create_bullets(3)
    bullets[1].archive!

    get daylog_bullets_path(before: bullets.last.id)

    assert_response :success
    assert_select '.bullet', 1
    assert_match 'Line 0', response.body
  end

  test 'index json returns older bullets as an array' do
    bullets = create_bullets(4)

    get daylog_bullets_path(before: bullets[2].id), as: :json

    assert_response :success
    body = response.parsed_body
    assert_equal 2, body.size
    assert_equal [bullets[0].id, bullets[1].id], body.map { |row| row['id'] }
    assert_equal 'Note', body.first['bulletable_type']
    assert_equal 'Line 0', body.first['body']
    assert body.first['url'].present?
  end

  test 'index json answers no content once exhausted' do
    bullets = create_bullets(2)

    get daylog_bullets_path(before: bullets.first.id), as: :json

    assert_response :no_content
  end

  test 'index json returns not modified when etag matches' do
    bullets = create_bullets(3)

    get daylog_bullets_path(before: bullets.last.id), as: :json

    assert_response :success
    etag = response.headers['ETag']
    assert etag.present?

    get daylog_bullets_path(before: bullets.last.id),
        as: :json,
        headers: { 'If-None-Match' => etag }

    assert_response :not_modified
  end

  test 'index json requires authentication' do
    sign_out
    bullets = create_bullets(2)

    get daylog_bullets_path(before: bullets.last.id), as: :json

    assert_response :unauthorized
    assert_equal 'Unauthorized', response.parsed_body['error']
  end

  private

  def create_bullets(count)
    Array.new(count) do |index|
      create_bullet!(@user, bulletable: Note.new(body: "Line #{index}"),
                            created_at: (count - index).minutes.ago)
    end
  end
end
