# frozen_string_literal: true

class User
  # Resolves Active Storage files through ownership chains rooted at a user.
  class Attachments
    def initialize(user)
      @user = user
    end

    def attachments
      ActiveStorage::Attachment
        .where(rich_text_condition.or(picture_condition).or(recording_condition))
        .includes(:blob)
        .order(created_at: :desc)
    end

    def find_blob!(signed_id)
      blob = ActiveStorage::Blob.find_signed!(signed_id)
      raise ActiveRecord::RecordNotFound unless attachments.where(blob_id: blob.id).exists?

      blob
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      raise ActiveRecord::RecordNotFound
    end

    private

    attr_reader :user

    def attachment_table = ActiveStorage::Attachment.arel_table

    def rich_text_condition
      attachment_table[:record_type].eq('ActionText::RichText')
                                    .and(attachment_table[:record_id].in(rich_text_ids.arel))
    end

    def picture_condition
      attachment_table[:record_type].eq('CalendarDate::Picture')
                                    .and(attachment_table[:record_id].in(picture_ids.arel))
    end

    def recording_condition
      attachment_table[:record_type].eq('Voice')
                                    .and(attachment_table[:record_id].in(voice_ids.arel))
    end

    def rich_text_ids
      ActionText::RichText.where(record_type: 'Bullet', record_id: user.bullets.select(:id)).select(:id)
    end

    def picture_ids
      CalendarDate::Picture.where(calendar_date_id: user.calendar_dates.select(:id)).select(:id)
    end

    def voice_ids
      Voice.joins(:bullet).where(bullets: { user_id: user.id }).select(:id)
    end
  end
end
