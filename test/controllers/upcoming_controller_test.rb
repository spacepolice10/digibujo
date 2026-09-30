# frozen_string_literal: true

require 'test_helper'

class UpcomingControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test 'show lists future bullets grouped by day, soonest first' do
    later = create_bullet!(@user, body: 'Next month', pops_on: Date.current + 30)
    sooner = create_bullet!(@user, body: 'Tomorrow', pops_on: Date.current + 1)

    get upcoming_path

    assert_response :success
    assert_select 'h1', text: 'Upcoming'
    assert_select '[role="separator"] time', count: 2
    assert_operator response.body.index(sooner.name), :<, response.body.index(later.name)
  end

  test 'show leaves out todays bullets, collections and archived ones' do
    create_bullet!(@user, body: 'On the timeline')
    create_bullet!(@user, body: 'Filed away', pops_on: Date.current + 2, collection: create_collection!(@user, name: 'Work'))
    create_bullet!(@user, body: 'Dropped', pops_on: Date.current + 2).archive!

    get upcoming_path

    assert_no_match 'On the timeline', response.body
    assert_no_match 'Filed away', response.body
    assert_no_match 'Dropped', response.body
    assert_select '.activity--empty', text: 'Nothing scheduled yet.'
  end

  test 'show does not list another users bullets' do
    create_bullet!(users(:two), body: 'Theirs', pops_on: Date.current + 2)

    get upcoming_path

    assert_no_match 'Theirs', response.body
  end

  test 'a future bullet offers the Today action in its checkbox traits' do
    create_bullet!(@user, body: 'Soon', pops_on: Date.current + 2)

    get upcoming_path

    assert_select 'input[data-bulk-scheduled="not-today"]', count: 1
  end
end
