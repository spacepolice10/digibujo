class LoginCode < ApplicationRecord
  EXPIRY = 15.minutes
  CODE_LENGTH = 6

  belongs_to :user

  before_create { self.expires_at = EXPIRY.from_now }

  def self.generate_code
    SecureRandom.alphanumeric(CODE_LENGTH).upcase
  end

  def self.digest(code)
    BCrypt::Password.create(code)
  end

  def self.create_for(user)
    code = generate_code
    record = user.login_codes.create!(code_digest: digest(code))
    [ record, code ]
  end

  def code_matches?(submitted)
    BCrypt::Password.new(code_digest).is_password?(submitted.to_s.strip.upcase)
  end

  def expired?
    expires_at < Time.current
  end

  def self.sweep
    where(expires_at: ...Time.current).delete_all
  end
end
