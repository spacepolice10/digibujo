# frozen_string_literal: true

module TimelinesHelper
  # Groups reading-ordered bullets into consecutive timeline sections. The
  # newest page always ends with today's section so the composer has a target
  # to append into even before the first bullet of the day exists.
  def timeline_sections(bullets, timeline, ensure_today: false)
    sections = bullets.group_by { |bullet| timeline.section_for(bullet.pops_on) }.to_a
    today = timeline.section_for(timeline.today)
    sections << [today, []] if ensure_today && sections.none? { |section, _| section == today }
    sections
  end
end
