# frozen_string_literal: true

module TimelinesHelper
  # Groups reading-ordered bullets into consecutive timeline sections.
  # `mount_today` keeps an empty Today section in the DOM as an append target;
  # CSS hides it until the first bullet arrives.
  def timeline_sections(bullets, timeline, mount_today: false)
    sections = bullets.group_by { |bullet| timeline.section_of(bullet.pops_on) }.to_a
    today = timeline.section_of(Date.current)
    sections << [today, []] if mount_today && sections.none? { |section, _| section == today }
    sections
  end
end
