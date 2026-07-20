# frozen_string_literal: true

module SessionTestHelper
  def sign_in_as(user)
    Current.session = user.sessions.create!

    ActionDispatch::TestRequest.create.cookie_jar.tap do |cookie_jar|
      cookie_jar.signed[:session_id] = Current.session.id
      cookies['session_id'] = cookie_jar[:session_id]
    end
  end

  def sign_out
    Current.session&.destroy!
    cookies.delete('session_id')
  end

  def request_login_code(email_address)
    ActionMailer::Base.deliveries.clear
    post authentication_path, params: { email_address: email_address }
    perform_enqueued_jobs
    login_code_from_last_email
  end

  def login_code_from_last_email
    mail = ActionMailer::Base.deliveries.last
    assert mail, 'expected a login code email'
    mail.body.encoded[/\b[A-Z0-9]{#{AuthCode::CODE_LENGTH}}\b/]
  end

  def confirm_login_code(code)
    post authentication_confirmation_path, params: { code: code }
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include SessionTestHelper
end
