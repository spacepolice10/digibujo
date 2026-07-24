# frozen_string_literal: true

require 'test_helper'

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400]

  include ActiveJob::TestHelper

  def sign_in_as(user)
    visit new_authentication_path

    session_record = user.sessions.create!
    cookie_jar = ActionDispatch::TestRequest.create.cookie_jar
    cookie_jar.signed[:session_id] = session_record.id

    page.driver.browser.manage.add_cookie(
      name: 'session_id',
      value: cookie_jar[:session_id],
      path: '/'
    )
  end
end
