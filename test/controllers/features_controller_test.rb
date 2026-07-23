# frozen_string_literal: true

require 'test_helper'

class FeaturesControllerTest < ActionDispatch::IntegrationTest
  test 'show is available without authentication' do
    get features_path

    assert_response :success
    assert_match 'Rapid logging', response.body
    assert_no_match 'Email code', response.body
  end

  test 'show includes create account call to action' do
    get features_path

    assert_response :success
    assert_select 'a[href=?]', new_authentication_path, text: /Create your own/
  end
end
