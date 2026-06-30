# frozen_string_literal: true

class Person::Handle < ApplicationRecord
  PLATFORMS = {
    'instagram' => { name: 'Instagram', link: 'https://instagram.com/%{data}' },
    'twitter' => { name: 'X / Twitter', link: 'https://x.com/%{data}' },
    'facebook' => { name: 'Facebook', link: 'https://facebook.com/%{data}' },
    'linkedin' => { name: 'LinkedIn', link: 'https://linkedin.com/in/%{data}' },
    'github' => { name: 'GitHub', link: 'https://github.com/%{data}' },
    'youtube' => { name: 'YouTube', link: 'https://youtube.com/@%{data}' },
    'tiktok' => { name: 'TikTok', link: 'https://tiktok.com/@%{data}' },
    'threads' => { name: 'Threads', link: 'https://threads.net/@%{data}' },
    'bluesky' => { name: 'Bluesky', link: 'https://bsky.app/profile/%{data}' },
    'telegram' => { name: 'Telegram', link: 'https://t.me/%{data}' },
    'whatsapp' => { name: 'WhatsApp', link: nil },
    'signal' => { name: 'Signal', link: nil },
    'mastodon' => { name: 'Mastodon', link: nil }
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
      link_template = PLATFORMS.dig(platform, :link)
      link_template ? format(link_template, data: normalized_data) : nil
    end
  end

  def display_name
    case kind.to_sym
    when :email, :phone
      normalized_data
    when :handle
      "#{platform_name}: #{normalized_data}"
    end
  end

  def platform_name
    PLATFORMS.dig(platform, :name) || platform.to_s.humanize
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
