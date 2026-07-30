# frozen_string_literal: true

require 'test_helper'

class HookIntakesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    Onboarding.new(user: @user).complete
    @hook = @user.hooks.create!(name: 'Zapier')
    @code = @hook.code
  end

  test 'create lands a note in pending with author_name' do
    assert_difference -> { @user.bullets.count }, 1 do
      post hook_intake_path(@code),
           params: {
             author_name: 'GitHub',
             bulletable_type: 'Note',
             body: 'Ship inbound hooks'
           },
           as: :json
    end

    assert_response :created
    body = response.parsed_body
    assert_equal 'Ship inbound hooks', body['body']
    assert_equal 'GitHub', body['author_name']
    assert_equal 'Note', body['bulletable_type']

    bullet = @user.bullets.find(body['id'])
    assert_equal @user.pending.bucket, bullet.bucket
    assert_nil bullet.pops_on
    assert_equal 'GitHub', bullet.author_name
  end

  test 'create accepts task type' do
    post hook_intake_path(@code),
         params: { bulletable_type: 'Task', body: 'Call mom' },
         as: :json

    assert_response :created
    assert_equal 'Task', response.parsed_body['bulletable_type']
  end

  test 'create rejects event and voice' do
    %w[Event Voice].each do |type|
      assert_no_difference -> { @user.bullets.count } do
        post hook_intake_path(@code),
             params: { bulletable_type: type, body: 'Nope' },
             as: :json
      end

      assert_response :unprocessable_entity
    end
  end

  test 'create with unknown code returns not found' do
    post hook_intake_path('hk_missing'),
         params: { bulletable_type: 'Note', body: 'Ghost' },
         as: :json

    assert_response :not_found
  end

  test 'create with inactive hook returns not found' do
    @hook.update!(active: false)

    post hook_intake_path(@code),
         params: { bulletable_type: 'Note', body: 'Ghost' },
         as: :json

    assert_response :not_found
  end

  test 'intake does not require authentication' do
    sign_out

    post hook_intake_path(@code),
         params: { author_name: 'CLI', bulletable_type: 'Note', body: 'Anon' },
         as: :json

    assert_response :created
  end
end
