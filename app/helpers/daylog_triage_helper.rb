# frozen_string_literal: true

# Builds concise, source-aware summaries for the daylog triage preview.
module DaylogTriageHelper
  def daylog_triage_summary(triage)
    clauses = []
    append_triage_clause(clauses, triage.monthlylog_bullets, 'planned in',
                         source: { emoji: '🗓️', label: 'Monthly log', variant: 'pill--accent' })
    append_triage_clause(clauses, triage.yesterday_bullets, 'to review from',
                         source: { emoji: '↩️', label: 'Yesterday', variant: 'pill--notify' })
    append_triage_clause(clauses, triage.pending_bullets, 'waiting in',
                         source: { emoji: '⚡', label: 'Pending', variant: 'pill--warning' })

    return 'Nothing needs your attention right now.' if clauses.empty?

    safe_join([safe_join(clauses, '. '), '.'])
  end

  private

  def append_triage_clause(clauses, bullets, context, source:)
    summary = bullet_type_summary(bullets)
    return if summary.blank?

    clauses << safe_join([
                           'You have ',
                           tag.span(summary, class: 'highlight'),
                           " #{context} ",
                           source_pill(**source)
                         ])
  end

  def source_pill(emoji:, label:, variant:)
    content = safe_join([tag.span(emoji, aria: { hidden: true }), label], ' ')
    tag.span(content, class: "pill #{variant}")
  end

  def bullet_type_summary(bullets)
    counts = bullets.group_by(&:bulletable_type).transform_values(&:size)
    Bullet.bulletable_types.filter_map do |type|
      count = counts[type]
      "#{count} #{type.downcase.pluralize(count)}" if count.to_i.positive?
    end.to_sentence
  end
end
