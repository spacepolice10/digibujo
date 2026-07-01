# frozen_string_literal: true

require 'test_helper'

module Daylogs
  class VoiceBulletsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      sign_in_as @user
      @selected_date = Date.current - 2.days
    end

    test 'new voice renders recorder composer' do
      get new_daylog_bullet_path(date: @selected_date, pops_on: @selected_date, bulletable_type: 'Voice'),
          headers: { 'Turbo-Frame' => 'bullet_composer' }

      assert_response :success
      assert_select 'turbo-frame#bullet_composer form.bullet-composer[data-controller=?]', 'composer voice-recorder'
      assert_select 'turbo-frame#bullet_composer .bullet-composer--rail .voice-recorder--controls'
      assert_select 'turbo-frame#bullet_composer .bullet-composer--type-pill[data-bullet-type=?]',
                    'voice', text: /Voice/
      assert_select 'turbo-frame#bullet_composer lexxy-editor[preset=?]:not([autofocus])', 'inline'
      assert_select 'turbo-frame#bullet_composer .voice-recorder--record[data-controller=?][data-hotkey=?]',
                    'hotkey', 'Shift+R'
      assert_select 'turbo-frame#bullet_composer .voice-recorder--record[data-action*="keydown.shift+r@document->hotkey#click"]'
      assert_select 'turbo-frame#bullet_composer .voice-recorder--preview [data-controller=?]', 'voice-player'
      assert_select 'turbo-frame#bullet_composer .voice-recorder--preview audio[controls]', count: 0
      assert_match "Record #{@selected_date.strftime('%a, %b %-d')}", response.body
    end

    test 'create voice appends playable bullet with caption and recording' do
      blob = create_voice_blob!

      assert_difference -> { @user.bullets.where(bulletable_type: 'Voice').count }, 1 do
        post daylog_bullets_path(date: @selected_date),
             params: voice_bullet_params(blob, body: 'Voice caption'),
             as: :turbo_stream
      end

      assert_response :success
      assert_turbo_stream action: 'append', target: 'bullets'
      assert_select '[data-controller=?]', 'voice-player'
      assert_select 'audio[src]'
      assert_voice_bullet_saved
    end

    test 'create voice without caption fails' do
      blob = create_voice_blob!

      assert_no_difference -> { @user.bullets.where(bulletable_type: 'Voice').count } do
        post daylog_bullets_path(date: @selected_date),
             params: voice_bullet_params(blob, body: ''),
             as: :turbo_stream
      end

      assert_response :unprocessable_entity
    end

    private

    def create_voice_blob!
      ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new('fake-audio'),
        filename: 'voice.webm',
        content_type: 'audio/webm'
      )
    end

    def voice_bullet_params(blob, body:)
      {
        bullet: {
          body: body,
          bulletable_type: 'Voice',
          pops_on: @selected_date.iso8601,
          bulletable_attributes: voice_attributes(blob)
        }
      }
    end

    def voice_attributes(blob)
      { recording: blob.signed_id, duration_seconds: 8 }
    end

    def assert_voice_bullet_saved
      voice_bullet = @user.bullets.where(bulletable_type: 'Voice').order(:created_at).last

      assert voice_bullet.bulletable.recording.attached?
      assert_equal 8, voice_bullet.bulletable.duration_seconds
    end
  end
end
