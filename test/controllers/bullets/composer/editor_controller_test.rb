# frozen_string_literal: true

require 'test_helper'

class Bullets::Composer::EditorControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test 'create returns inline editor for Task' do
    post composer_editor_path,
         params: { bulletable_type: 'Task', body: '<p>hello</p>' }

    assert_response :success
    assert_select 'turbo-frame#composer_editor'
    assert_select 'lexxy-editor[preset=inline]'
    assert_select 'lexxy-editor[preset=note]', false
    assert_match 'hello', response.body
  end

  test 'create returns note editor for Note' do
    post composer_editor_path,
         params: { bulletable_type: 'Note', body: '<h1>detail</h1>' }

    assert_response :success
    assert_select 'turbo-frame#composer_editor'
    assert_select 'lexxy-editor[preset=note]'
    assert_select 'lexxy-editor[preset=inline]', false
    assert_match 'detail', response.body
  end

  test 'create requires bulletable_type' do
    post composer_editor_path, params: { body: '<p>hello</p>' }

    assert_response :bad_request
  end

  test 'create requires authentication' do
    delete session_path
    post composer_editor_path, params: { bulletable_type: 'Task' }

    assert_redirected_to new_session_path
  end
end
