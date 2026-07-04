class CreateComposer
  PRESETS = {
    'Task' => 'inline',
    'Note' => 'note',
    'Voice' => 'inline',
    'Event' => 'inline'
  }.freeze

  MENTION_ATTACHMENT_TYPES = %w[
    application/vnd.actiontext.project
    application/vnd.actiontext.person
  ].freeze

  # nil == unrestricted (files + mentions). An array == allowlist of
  # attachment content types, which blocks file uploads while still
  # accepting the custom # / @ attachables listed.
  PERMITTED_ATTACHMENT_TYPES = {
    'Task' => MENTION_ATTACHMENT_TYPES,
    'Note' => nil,
    'Voice' => MENTION_ATTACHMENT_TYPES,
    'Event' => MENTION_ATTACHMENT_TYPES
  }.freeze

  TOOLBAR_IDS = {
    'Task' => 'toolbar-task',
    'Note' => 'toolbar-note',
    'Voice' => 'toolbar-voice',
    'Event' => 'toolbar-event'
  }.freeze

  FOCUSING_ON_RENDER = {
    'Task' => true,
    'Note' => true,
    'Voice' => false,
    'Event' => true
  }.freeze

  PLACEHOLDERS = {
    'Task' => 'What need to be done?',
    'Note' => 'Add markdown notes, files or images...',
    'Voice' => 'Caption this voice memo…',
    'Event' => 'What is upcoming?'
  }.freeze

  STIMULUS_CONTROLLERS = {
    'Task' => 'composer',
    'Note' => 'composer',
    'Voice' => 'composer voice-recorder',
    'Event' => 'composer'
  }.freeze

  STIMULUS_ACTIONS = {
    'Task' => 'keydown.enter+meta->composer#submit keydown.enter+ctrl->composer#submit turbo:submit-end->composer#clearOnSubmit',
    'Note' => 'keydown.enter+meta->composer#submit keydown.enter+ctrl->composer#submit turbo:submit-end->composer#clearOnSubmit',
    'Voice' => 'turbo:submit-end->voice-recorder#clearOnSubmit',
    'Event' => 'keydown.enter+meta->composer#submit keydown.enter+ctrl->composer#submit turbo:submit-end->composer#clearOnSubmit'
  }.freeze

  def initialize(bullet:, bulletable_type:)
    @bullet = bullet
    @bulletable_type = bulletable_type
  end

  def bulletable
    return unless @bullet.bulletable_type

    @bullet.bulletable || @bullet.bulletable_type.constantize.new
  end

  def preset
    PRESETS[@bulletable_type]
  end

  def permitted_attachment_types
    PERMITTED_ATTACHMENT_TYPES[@bulletable_type]
  end

  # HTML attributes to splat onto the <lexxy-editor> / rich_text_area.
  # Lexxy reads the per-editor override from the dasherized config key and
  # JSON-parses the value.
  def editor_html_options
    types = permitted_attachment_types
    types ? { "permitted-attachment-types": types.to_json } : {}
  end

  def toolbar_id
    TOOLBAR_IDS[@bulletable_type]
  end

  def focusing_on_render?
    FOCUSING_ON_RENDER[@bulletable_type]
  end

  def placeholder
    PLACEHOLDERS[@bulletable_type]
  end

  def stimulus_controller
    STIMULUS_CONTROLLERS[@bulletable_type]
  end

  def stimulus_actions
    STIMULUS_ACTIONS[@bulletable_type]
  end

  def form_extras
    case @bulletable_type
    when 'Note' then 'notes/composer_extras'
    when 'Voice' then 'voices/composer_extras'
    end
  end

  def call
    {
      preset: preset,
      focusing_on_render: focusing_on_render?,
      placeholder: placeholder,
      stimulus_controller: stimulus_controller,
      stimulus_actions: stimulus_actions,
      form_extras: form_extras
    }
  end
end
