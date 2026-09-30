# frozen_string_literal: true

# The single feed of a user's bullets. Sections are computed from each bullet's
# day relative to today — nothing is stored.
class Timeline
  DAY_SPAN = 7

  Section = Data.define(:key, :label)

  def initialize(user, today: Date.current)
    @user = user
    @today = today
  end

  attr_reader :user, :today

  def bullets
    user.bullets.on_timeline.active.due(today)
  end

  def upcoming
    user.bullets.on_timeline.active.upcoming(today)
  end

  def last_page
    bullets.last_day_page
  end

  def page_before(bullet)
    bullets.day_page_before(bullet)
  end

  def section_for(date)
    self.class.section_for(date, today: today)
  end

  def self.section_for(date, today: Date.current)
    age = (today - date.to_date).to_i

    case age
    when ..0 then Section.new('today', 'Today')
    when 1 then Section.new('yesterday', 'Yesterday')
    when 2...DAY_SPAN then Section.new(date.to_date.iso8601, date.to_date.strftime('%A, %b %-d'))
    when DAY_SPAN..13 then Section.new('last-week', 'Last week')
    when 14..30 then Section.new('last-month', 'Last month')
    when 31..90 then Section.new('last-3-months', 'Last 3 months')
    when 91..365 then Section.new('last-year', 'Last year')
    else Section.new("year-#{date.to_date.year}", date.to_date.year.to_s)
    end
  end
end
