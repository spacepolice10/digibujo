# frozen_string_literal: true

require 'test_helper'

class HooksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test 'create returns the code and intake url once' do
    assert_difference -> { @user.hooks.count }, 1 do
      post hooks_path,
           params: { hook: { name: 'Zapier' } },
           as: :json
    end

    assert_response :created
    body = response.parsed_body
    assert_equal 'Zapier', body['name']
    assert body['code'].start_with?('hk_')
    assert_includes body['url'], "/hooks/#{body['code']}"
    assert_nil Hook.find(body['id']).code
  end

  test 'index omits code and digest' do
    hook = @user.hooks.create!(name: 'Listed')

    get hooks_path, as: :json

    assert_response :success
    row = response.parsed_body.find { |item| item['id'] == hook.id }
    assert_equal hook.code_prefix, row['code_prefix']
    assert_nil row['code']
    assert_nil row['code_digest']
  end

  test 'destroy removes the hook' do
    hook = @user.hooks.create!(name: 'Old')

    assert_difference -> { @user.hooks.count }, -1 do
      delete hook_path(hook), as: :json
    end

    assert_response :no_content
  end

  test 'html index lists hooks and links to create' do
    hook = @user.hooks.create!(name: 'Relay')

    get hooks_path

    assert_response :success
    assert_select '.layout--container-header h1', text: 'Hooks'
    assert_select 'a.button[data-content="text"][aria-label="Back to Account"]', text: /Account/
    assert_select 'form[action=?]', hooks_path, count: 0
    assert_select 'a.button.layout--container-header-action[href=?]', new_hook_path, text: /Create/
    assert_match hook.name, response.body
    assert_match hook.code_prefix, response.body
    assert_select 'button.button[data-status="negative"]', text: /Revoke/
  end

  test 'html new renders the create form and docs' do
    get new_hook_path

    assert_response :success
    assert_select '.layout--container-header h1', text: 'New hook'
    assert_select 'a.button[data-content="text"][aria-label="Back to Hooks"]', text: /Hooks/
    assert_select 'form[action=?]', hooks_path
    assert_select 'input[type="submit"][data-intent="primary"]'
    assert_match 'bulletable_type', response.body
  end

  test 'html create shows the intake url once on index' do
    assert_difference -> { @user.hooks.count }, 1 do
      post hooks_path, params: { hook: { name: 'Zapier' } }
    end

    assert_redirected_to hooks_path
    follow_redirect!

    assert_match(/Copy this URL now/, response.body)
    assert_match(%r{/hooks/hk_}, response.body)
    assert_match 'Zapier', response.body
    assert_select 'section.hooks--created[role="status"]' do
      assert_select 'strong', text: 'Hook is ready'
      assert_select '[aria-hidden="true"]', text: '⚡'
      assert_select 'code.hooks--created-url'
    end

    get hooks_path

    assert_no_match(/Copy this URL now/, response.body)
    assert_select 'section.hooks--created', count: 0
  end

  test 'html destroy revokes the hook' do
    hook = @user.hooks.create!(name: 'Old')

    assert_difference -> { @user.hooks.count }, -1 do
      delete hook_path(hook)
    end

    assert_redirected_to hooks_path
  end
end
