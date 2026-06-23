# frozen_string_literal: true

# rubocop:disable Style/ClassAndModuleChildren
class Person::Handle < ApplicationRecord
  PLATFORMS = {
    'instagram' => { label: 'Instagram', url: 'https://instagram.com/%{data}' },
    'twitter' => { label: 'X / Twitter', url: 'https://x.com/%{data}' },
    'facebook' => { label: 'Facebook', url: 'https://facebook.com/%{data}' },
    'linkedin' => { label: 'LinkedIn', url: 'https://linkedin.com/in/%{data}' },
    'github' => { label: 'GitHub', url: 'https://github.com/%{data}' },
    'youtube' => { label: 'YouTube', url: 'https://youtube.com/@%{data}' },
    'tiktok' => { label: 'TikTok', url: 'https://tiktok.com/@%{data}' },
    'threads' => { label: 'Threads', url: 'https://threads.net/@%{data}' },
    'bluesky' => { label: 'Bluesky', url: 'https://bsky.app/profile/%{data}' },
    'telegram' => { label: 'Telegram', url: 'https://t.me/%{data}' },
    'whatsapp' => { label: 'WhatsApp', url: nil },
    'signal' => { label: 'Signal', url: nil },
    'mastodon' => { label: 'Mastodon', url: nil }
  }.freeze

  enum :kind, { email: 0, phone: 1, handle: 2 }

  belongs_to :person, touch: true

  validates :data, presence: true
  validates :platform, absence: true, unless: :handle?
  validates :platform, presence: true, inclusion: { in: PLATFORMS.keys }, if: :handle?
  validates :data, format: { with: URI::MailTo::EMAIL_REGEXP }, if: :email?

  before_validation :normalize_data

  def href
    case kind.to_sym
    when :email
      "mailto:#{normalized_data}"
    when :phone
      "tel:#{normalized_data}"
    when :handle
      url_template = PLATFORMS.dig(platform, :url)
      url_template ? format(url_template, data: normalized_data) : nil
    end
  end

  def display_label
    case kind.to_sym
    when :email, :phone
      normalized_data
    when :handle
      "#{platform_label}: #{normalized_data}"
    end
  end

  def platform_label
    PLATFORMS.dig(platform, :label) || platform.to_s.humanize
  end

  def normalized_data
    data.to_s
  end

  private

  def normalize_data
    return if data.blank?

    self.data = data.strip
    self.data = data.downcase if email?
    self.data = data.delete_prefix('@') if handle?
  end
end
# rubocop:enable Style/ClassAndModuleChildren
