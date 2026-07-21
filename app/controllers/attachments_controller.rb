# frozen_string_literal: true

class AttachmentsController < ApplicationController
  def show
    @blob = ActiveStorage::Blob.find_signed!(params[:signed_id])
    raise ActiveRecord::RecordNotFound unless owned_by_current_user?(@blob)
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    raise ActiveRecord::RecordNotFound
  end

  private

  def owned_by_current_user?(blob)
    rich_text_ids = ActiveStorage::Attachment
      .where(blob_id: blob.id, record_type: 'ActionText::RichText')
      .select(:record_id)

    note_ids = ActionText::RichText
      .where(id: rich_text_ids, record_type: 'Note')
      .select(:record_id)

    Current.user.bullets.exists?(bulletable_type: 'Note', bulletable_id: note_ids)
  end
end
