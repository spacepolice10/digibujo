# frozen_string_literal: true

require 'test_helper'

class PinnedControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test 'index renders workspace on mobile (direct visit)' do
    get pinned_index_path, headers: { 'User-Agent' => 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0)' }

    assert_response :success
    assert_select '.workspace'
  end

  test 'mobile workspace lists pinned bullets' do
    bullet = @user.bullets.create!(
      bulletable: Task.create!,
      body: 'Pinned bullet'
    )
    PinnedEntity.create!(user: @user, pinnable: bullet)

    get pinned_index_path, headers: { 'User-Agent' => 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0)' }

    assert_response :success
    assert_select '.workspace .bullet', text: /Pinned bullet/, count: 1
  end

  test 'mobile workspace lists pinned project bullets' do
    project = create_project!(@user, name: 'footer project')
    project.pin!
    bullet = @user.bullets.create!(
      bulletable: Task.create!,
      body: 'Project bullet',
      pops_on: Date.current
    )
    bullet.tag_project!(project_id: project.id)

    get pinned_index_path, headers: { 'User-Agent' => 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0)' }

    assert_response :success
    assert_select '.workspace .bullet', text: /Project bullet/, count: 1
  end

  test 'pinned bullets popover loads bullets on request' do
    bullet = @user.bullets.create!(
      bulletable: Task.create!,
      body: 'Pinned bullet'
    )
    PinnedEntity.create!(user: @user, pinnable: bullet)

    get pinned_index_path, headers: { 'Turbo-Frame' => 'pinned_bullets' }

    assert_select 'turbo-frame#pinned_bullets[popover].pinned--list' do
      assert_select '.dropdown--header h2', count: 0
      assert_select "button.bulk-menu--hide[popovertarget='pinned_bullets'][popovertargetaction='hide'][aria-label='Close pinned bullets']"
      assert_select '.bullet-compact', text: /Pinned bullet/, count: 1
    end
  end
end
