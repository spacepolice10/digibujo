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
    note_attachment_owned?(blob) || picture_owned?(blob)
  end

  def note_attachment_owned?(blob)
    rich_text_ids = ActiveStorage::Attachment
                    .where(blob_id: blob.id, record_type: 'ActionText::RichText')
                    .select(:record_id)

    note_ids = ActionText::RichText
               .where(id: rich_text_ids, record_type: 'Note')
               .select(:record_id)

    Current.user.bullets.exists?(bulletable_type: 'Note', bulletable_id: note_ids)
  end

  def picture_owned?(blob)
    CalendarDate::Picture.joins(:calendar_date, :picture_attachment)
                         .where(calendar_dates: { user_id: Current.user.id })
                         .exists?(active_storage_attachments: { blob_id: blob.id })
  end
end
