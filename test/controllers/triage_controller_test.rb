# frozen_string_literal: true

require 'test_helper'

class TriageControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    ensure_daylog!(@user)
    @pending = Pending.provision!(@user)
  end

  test 'show lists pending bullets' do
    bullet = create_bullet!(@user, bucket: @pending.bucket, bulletable: Note.new, body: 'From extension', pops_on: nil)

    get triage_path

    assert_response :success
    assert_match 'From extension', response.body
    assert_select "form[action=?]", triage_bullet_accept_path(bullet)
  end

  test 'show lists pending and monthlylog today bullets' do
    monthlylog = create_monthlylog!(@user, name: 'This month')
    create_bullet!(
      @user,
      bucket: monthlylog.bucket,
      bulletable: Task.new, body: 'Monthly today',
      pops_on: Date.current
    )
    create_bullet!(
      @user,
      bucket: monthlylog.bucket,
      bulletable: Task.new, body: 'Monthly tomorrow',
      pops_on: Date.current + 1.day
    )
    create_bullet!(
      @user,
      bucket: monthlylog.bucket,
      bulletable: Note.new, body: 'Monthly unplanned',
      pops_on: nil
    )

    get triage_path

    assert_response :success
    assert_match 'Monthly today', response.body
    assert_no_match 'Monthly tomorrow', response.body
    assert_no_match 'Monthly unplanned', response.body
  end

  test 'show excludes archived bullets' do
    create_bullet!(@user, bucket: @pending.bucket, bulletable: Note.new, body: 'Inbox me', pops_on: nil)
    archived = create_bullet!(@user, bucket: @pending.bucket, bulletable: Note.new, body: 'Archived me', pops_on: nil)
    archived.archive!

    get triage_path

    assert_response :success
    assert_match 'Inbox me', response.body
    assert_no_match 'Archived me', response.body
  end

  test 'show is empty when nothing is pending' do
    get triage_path

    assert_response :success
    assert_match 'Nothing pending right now', response.body
  end
end
