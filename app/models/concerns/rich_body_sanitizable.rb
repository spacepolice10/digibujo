# frozen_string_literal: true

module RichBodySanitizable
  extend ActiveSupport::Concern

  TAG_ATTACHABLE_TYPES = [Project, Person].freeze

  def sanitize_rich_body_tag_attachables!
    rich_text = ActionText::RichText.find_by(record: self, name: 'rich_body')
    return unless rich_text&.body.present?

    stripped = strip_tag_attachables_from_html(rich_text.body.to_s)
    return if stripped == rich_text.body.to_s

    rich_text.update!(body: stripped)
  end

  private

  def strip_tag_attachables_from_html(html)
    ActionText::Fragment.wrap(html).replace(ActionText::Attachment.tag_name) do |node|
      attachment = ActionText::Attachment.from_node(node)
      TAG_ATTACHABLE_TYPES.any? { |type| attachment.attachable.is_a?(type) } ? '' : node
    end.to_html
  end
end
