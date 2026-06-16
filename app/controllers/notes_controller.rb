# frozen_string_literal: true

class NotesController < ApplicationController
  before_action :ensure_turbo_frame_request, only: :index, if: :turbo_frame_request?

  NOTE_LIMIT = 10

  def index
    @notes = Note.joins(:bullet)
                 .where(bullets: { user_id: Current.user.id })
                 .where('notes.idea = ? OR notes.awaits_research = ?', true, true)
                 .includes(bullet: :projects)
                 .order(created_at: :desc)
                 .limit(NOTE_LIMIT)
  end

  private

  def turbo_frame_request?
    request.headers['Turbo-Frame'].present?
  end

  def ensure_turbo_frame_request
    head :not_found unless request.headers['Turbo-Frame'] == 'menu_notes'
  end
end
