# frozen_string_literal: true

require 'test_helper'

class VoiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new('fake-audio'),
      filename: 'voice.webm',
      content_type: 'audio/webm'
    )
  end

  test 'requires recording and duration within cap' do
    voice = Voice.new(duration_seconds: 5)
    voice.recording.attach(@blob)

    assert voice.valid?
  end

  test 'rejects duration over max' do
    voice = Voice.new(duration_seconds: Voice::DURATION_SECONDS + 1)
    voice.recording.attach(@blob)

    assert voice.invalid?
    assert_includes voice.errors[:duration_seconds], "must be in 1..#{Voice::DURATION_SECONDS}"
  end

  test 'rejects zero duration' do
    voice = Voice.new(duration_seconds: 0)
    voice.recording.attach(@blob)

    assert voice.invalid?
  end

  test 'rejects unsupported content type' do
    bad_blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new('fake-audio'),
      filename: 'voice.mp3',
      content_type: 'audio/mpeg'
    )
    voice = Voice.new(duration_seconds: 5)
    voice.recording.attach(bad_blob)

    assert voice.invalid?
    assert_includes voice.errors[:recording], 'has an invalid content type'
  end

  test 'accepts browser codec suffix on supported content type' do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new('fake-audio'),
      filename: 'voice.webm',
      content_type: 'audio/webm;codecs=opus'
    )
    voice = Voice.new(duration_seconds: 5)
    voice.recording.attach(blob)

    assert voice.valid?
  end

  test 'saves through bullet with caption and recording' do
    bullet = @user.bullets.new(
      bulletable_type: 'Voice',
      body: 'Morning memo',
      bulletable_attributes: {
        recording: @blob.signed_id,
        duration_seconds: 12
      }
    )

    assert_difference -> { Voice.count }, 1 do
      assert bullet.save, bullet.errors.full_messages.to_sentence
    end

    assert bullet.bulletable.recording.attached?
    assert_equal 12, bullet.bulletable.duration_seconds
  end
end
