# frozen_string_literal: true

module BulletsHelper
  COMPOSER_TYPES = {
    "Task" => { icon: "square", modifier: "task", hotkey: "Shift+T" },
    "Note" => { icon: "line-dashed", modifier: "note", hotkey: "Shift+N" },
    "Event" => { icon: "circle", modifier: "event", hotkey: "Shift+E" },
    "Voice" => { icon: "microphone", modifier: "voice", hotkey: "Shift+V" }
  }.freeze

  def composer_type_options(path_builder, **extra_params)
    Bullet.bulletable_types.filter_map do |type_name|
      meta = COMPOSER_TYPES[type_name]
      next unless meta

      {
        path: path_builder.call(bulletable_type: type_name, **extra_params),
        name: type_name,
        icon: meta[:icon],
        modifier: meta[:modifier],
        hotkey: meta[:hotkey]
      }
    end
  end
end
