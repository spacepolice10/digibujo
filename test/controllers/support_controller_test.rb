# frozen_string_literal: true

require 'test_helper'

class SupportControllerTest < ActionDispatch::IntegrationTest
  test 'show is available without authentication' do
    get support_path

    assert_response :success
    assert_select 'a[href=?]', 'mailto:naysdemo@zohomail.com'
    assert_select 'a[href=?]', 'https://github.com/spacepolice10/digibujo'
  end
end
