# frozen_string_literal: true

require 'test_helper'

class AccessCodesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test 'create returns the code once' do
    assert_difference -> { @user.access_codes.count }, 1 do
      post access_codes_path,
           params: { access_code: { description: 'CLI' } },
           as: :json
    end

    assert_response :created
    body = response.parsed_body
    assert body['code'].start_with?('dj_')
    assert_equal 'CLI', body['description']
    assert_nil AccessCode.find(body['id']).code
  end

  test 'index omits code and digest' do
    access_code = @user.access_codes.create!(description: 'Listed')

    get access_codes_path, as: :json

    assert_response :success
    row = response.parsed_body.find { |item| item['id'] == access_code.id }
    assert_equal access_code.code_prefix, row['code_prefix']
    assert_nil row['code']
    assert_nil row['code_digest']
  end

  test 'destroy removes the access code' do
    access_code = @user.access_codes.create!

    assert_difference -> { @user.access_codes.count }, -1 do
      delete access_code_path(access_code), as: :json
    end

    assert_response :no_content
  end

  test 'access code can create bullets' do
    sign_out
    access_code = @user.access_codes.create!
    code = access_code.code
    daylog = ensure_daylog!(@user)

    assert_difference -> { @user.bullets.count }, 1 do
      post bullets_path,
           params: {
             bullet: {
               bulletable_type: 'Note',
               body: '<p>Access code note</p>',
               pops_on: Date.current.iso8601,
               bucket_id: daylog.id
             }
           },
           headers: { 'Authorization' => "Bearer #{code}" },
           as: :json
    end

    assert_response :created
    assert_equal 'Access code note', response.parsed_body['body']
  end

  test 'html index lists codes' do
    access_code = @user.access_codes.create!(description: 'Laptop')

    get access_codes_path

    assert_response :success
    assert_select '.layout--container-header h1', text: 'Access codes'
    assert_select 'a.button[data-content="text"][aria-label="Back to Account"]', text: /Account/
    assert_select '#access_codes .layout--surface[data-elevation="2"]'
    assert_select 'form[action=?]', access_codes_path, count: 0
    assert_match access_code.code_prefix, response.body
    assert_select 'button.button[data-status="negative"]', text: /Revoke/
  end

  test 'html destroy revokes the access code' do
    access_code = @user.access_codes.create!(description: 'Old')

    assert_difference -> { @user.access_codes.count }, -1 do
      delete access_code_path(access_code)
    end

    assert_redirected_to access_codes_path
  end
end
