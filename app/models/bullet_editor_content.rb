# frozen_string_literal: true

class BulletEditorContent
  def self.hydrate(html)
    return html if html.blank?

    ActionText::Fragment.wrap(html).replace(ActionText::Attachment.tag_name) do |node|
      next node unless node["url"].blank?

      attachment = ActionText::Attachment.from_node(node)
      node["content"] = attachment_content_json(attachment)
      node["content-type"] ||= attachment.content_type
      node
    end.to_html
  end

  def self.attachment_content_json(attachment)
    attachable = attachment.attachable
    partial_locals = editor_partial_locals_for(attachable)

    html = if partial_locals
      ApplicationController.render(partial: partial_locals[:partial], locals: partial_locals[:locals]).chomp
    else
      ApplicationController.helpers.render_action_text_attachment(attachment)
    end

    html.to_json
  end

  def self.editor_partial_locals_for(attachable)
    case attachable
    when Project then { partial: "projects/attachable_editor", locals: { project: attachable } }
    when Person then { partial: "people/attachable_editor", locals: { person: attachable } }
    end
  end

  private_class_method :attachment_content_json, :editor_partial_locals_for
end
