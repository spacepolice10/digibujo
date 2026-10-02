# frozen_string_literal: true

# The single feed of a user's bullets. Sections are computed from each bullet's
# day relative to today — nothing is stored.
class Timeline
  DAY_SPAN = 7

  Section = Data.define(:key, :label)

  def initialize(user, filter: nil, today: Date.current)
    @user = user
    @today = today.to_date
    @filter = filter || Bullet::Filter.from_params({}, user: user, today: @today)
  end

  attr_reader :user, :today, :filter

  def bullets
    filter.apply(user.bullets.active)
  end

  def upcoming
    user.bullets.active.upcoming(today)
  end

  def last_page
    bullets.last_day_page
  end

  def page_before(bullet)
    bullets.day_page_before(bullet)
  end

  def section_of(date)
    self.class.section_of(date, today: today)
  end

  def self.section_of(date, today: Date.current)
    day = date.to_date
    return Section.new(day.iso8601, day.strftime('%A, %b %-d')) if day > today.to_date

    age = (today.to_date - day).to_i

    case age
    when 0 then Section.new('today', 'Today')
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
