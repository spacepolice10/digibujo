# frozen_string_literal: true

require 'test_helper'

class CompletedControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test 'index lists done bullets newest first' do
    old = create_bullet!(@user, body: 'Old done')
    old.complete!
    old.update!(done_at: 2.days.ago)
    fresh = create_bullet!(@user, body: 'Fresh done')
    fresh.complete!
    create_bullet!(@user, body: 'Not done')

    get completed_index_path

    assert_response :success
    assert_select 'main h1', 'Completed'
    assert_includes response.body, 'Fresh done'
    assert_includes response.body, 'Old done'
    assert_not_includes response.body, 'Not done'
    assert_operator response.body.index('Fresh done'), :<, response.body.index('Old done')
  end
end
