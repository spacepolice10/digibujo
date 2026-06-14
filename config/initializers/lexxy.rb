# frozen_string_literal: true

Rails.application.config.to_prepare do
  module Digibujo::LexxyEditorAttachments
    def render_custom_attachments_in(value)
      if value.is_a?(ActionText::Content)
        html = value.fragment.to_html.presence
        return value unless html

        hydrate_editor_attachments(html)
      else
        super
      end
    end

    private

      def hydrate_editor_attachments(html)
        self.prefix_partial_path_with_controller_namespace = false if respond_to?(:prefix_partial_path_with_controller_namespace=)
        ActionText::Fragment.wrap(html).replace(ActionText::Attachment.tag_name) do |node|
          if node["url"].blank?
            attachment = ActionText::Attachment.from_node(node)
            node["content"] = render_editor_attachment_content(attachment).to_json
            node["content-type"] ||= attachment.content_type
          end
          node
        end.to_html
      end

      def render_editor_attachment_content(attachment)
        attachable = attachment.attachable
        if attachable.is_a?(Project)
          ApplicationController.render(
            partial: "projects/attachable_editor",
            locals: { project: attachable }
          ).chomp
        else
          render_action_text_attachment(attachment)
        end
      end
  end

  Lexxy::TagHelper.prepend(Digibujo::LexxyEditorAttachments)
end
