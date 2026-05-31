# frozen_string_literal: true

module BulletsHelper
  def bullet_type_options
    Bullet.bulletable_types
  end

  def bullet_type_descriptions
    {
      "Note" => "Capture an idea or detail",
      "Task" => "Track an actionable item",
      "Event" => "Plan something time-based"
    }
  end

end

