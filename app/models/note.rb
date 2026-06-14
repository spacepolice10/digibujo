class Note < ApplicationRecord
  include Bulletable

  enum :mood, { positive: 0, negative: 1, inspired: 2, frustrated: 3 }

  def mark_as_awaits_research!
    update!(awaits_research: true)
  end

  def unmark_as_awaits_research!
    update!(awaits_research: false)
  end

  def mark_as_idea!
    update!(idea: true)
  end

  def unmark_as_idea!
    update!(idea: false)
  end

  def temporal?      = false
  def completable?   = false
  def marker_styles  = "bullet--note-marker"

  def body
    excerpt
  end

  def excerpt
    text = bullet.content.to_plain_text
    if text.length > 400
      text.truncate(400) || "Untitled"
    else
      bullet.content
    end
  end

  def mood_marker
    case mood&.to_sym
    when :positive   then "😊"
    when :negative   then "😞"
    when :inspired   then "✨"
    when :frustrated then "😣"
    end
  end

  def meta_labels
    [].tap do |labels|
      labels << { emoji: "🔬", colour: "amber" } if awaits_research?
      labels << { emoji: "💡", colour: "purple" } if idea?
    end
  end

  def self.bulletable_form_fields? = true
end
