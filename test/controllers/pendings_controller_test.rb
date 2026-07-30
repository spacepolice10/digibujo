# frozen_string_literal: true

require 'test_helper'

class PendingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    ensure_daylog!(@user)
    @pending = Pending.provision!(@user)
  end

  test 'show lists pending bullets' do
    bullet = create_bullet!(@user, bucket: @pending.bucket, bulletable: Note.new(body: 'From extension'), pops_on: nil)

    get pending_path

    assert_response :success
    assert_match 'From extension', response.body
    assert_select "form[action=?]", pending_bullet_accept_path(bullet)
  end

  test 'show as turbo frame renders pending dropdown' do
    create_bullet!(@user, bucket: @pending.bucket, bulletable: Note.new(body: 'In dropdown'), pops_on: nil)

    get pending_path, headers: { 'Turbo-Frame' => 'pending_list' }

    assert_response :success
    assert_select 'turbo-frame#pending_list[popover].daylog--pending-dropdown' do
      assert_match 'In dropdown', response.body
      assert_select "form[action=?]", pending_bullet_accept_path(@pending.bullets.first)
    end
  end

  test 'show lists current monthlylog bullets planned for today' do
    monthlylog = create_monthlylog!(@user, name: 'This month')
    create_bullet!(
      @user,
      bucket: monthlylog.bucket,
      bulletable: Task.new(body: 'Monthly today'),
      pops_on: Date.current
    )
    create_bullet!(
      @user,
      bucket: monthlylog.bucket,
      bulletable: Task.new(body: 'Monthly tomorrow'),
      pops_on: Date.current + 1.day
    )
    create_bullet!(
      @user,
      bucket: monthlylog.bucket,
      bulletable: Note.new(body: 'Monthly unplanned'),
      pops_on: nil
    )

    get pending_path

    assert_response :success
    assert_match 'Monthly today', response.body
    assert_no_match 'Monthly tomorrow', response.body
    assert_no_match 'Monthly unplanned', response.body
  end

  test 'show is empty when nothing is pending' do
    get pending_path

    assert_response :success
    assert_match 'Nothing pending right now', response.body
  end
end
