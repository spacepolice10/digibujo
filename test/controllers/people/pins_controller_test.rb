# frozen_string_literal: true

require 'test_helper'

module People
  class PinsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      sign_in_as @user
      @person = @user.people.create!(name: 'Alex')
    end

    test 'create pins person and updates pin button via turbo stream' do
      post people_pin_path,
           params: { person_id: @person.id },
           headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      assert_response :success
      assert @person.reload.pinned?
      assert_match 'turbo-stream', response.media_type
      assert_match dom_id(@person, :pin_button), response.body
    end

    test 'destroy unpins person and updates pin button via turbo stream' do
      @person.pin!

      delete people_pin_path,
             params: { person_id: @person.id },
             headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      assert_response :success
      assert_not @person.reload.pinned?
      assert_match dom_id(@person, :pin_button), response.body
    end

    test 'create redirects html requests back to people index' do
      post people_pin_path, params: { person_id: @person.id }

      assert_redirected_to people_path
      assert @person.reload.pinned?
    end
  end
end
