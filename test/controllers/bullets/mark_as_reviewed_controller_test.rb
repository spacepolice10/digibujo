# frozen_string_literal: true

require 'test_helper'

class Bullets::MarkAsReviewedControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    @today = Date.current
  end

  test 'create marks all bullets in review period' do
    in_review = @user.bullets.create!(bulletable: Task.new(body: 'Keep as is'), pops_on: @today)
    @user.bullets.create!(bulletable: Note.new(body: 'Already reviewed'), pops_on: @today).tap(&:mark_as_reviewed!)

    post mark_as_reviewed_path, params: { from: @today.iso8601, to: @today.iso8601 }

    assert_redirected_to review_path(from: @today.iso8601, to: @today.iso8601)
    assert in_review.reload.migrated?
    assert_equal 'acknowledged', in_review.last_migration['action']

    follow_redirect!
    assert_select '#review-amount-in-review', text: '0'
    assert_select '.review--to-review-empty', text: 'Nothing to review'
  end

  test 'create with bullet_ids marks only selected bullets' do
    first = @user.bullets.create!(bulletable: Task.new(body: 'First'), pops_on: @today)
    second = @user.bullets.create!(bulletable: Task.new(body: 'Second'), pops_on: @today)

    post mark_as_reviewed_path,
         params: { from: @today.iso8601, to: @today.iso8601, bullet_ids: first.id.to_s }

    assert_redirected_to review_path(from: @today.iso8601, to: @today.iso8601)
    assert first.reload.migrated?
    assert_not second.reload.migrated?
  end

  test 'create rejects bullet_ids outside review scope' do
    collection = create_collection!(@user, name: 'Work')
    collected = @user.bullets.create!(
      bulletable: Task.new(body: 'Collected'),
      pops_on: @today,
      bucket_id: collection.bucket.id
    )

    post mark_as_reviewed_path,
         params: { from: @today.iso8601, to: @today.iso8601, bullet_ids: collected.id.to_s }

    assert_response :not_found
    assert_not collected.reload.migrated?
  end

  test 'create requires authentication' do
    sign_out

    post mark_as_reviewed_path, params: { from: @today.iso8601, to: @today.iso8601 }

    assert_redirected_to new_authentication_path
  end
end
