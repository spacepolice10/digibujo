# frozen_string_literal: true

require 'test_helper'

class Bullet::ParamsTest < ActiveSupport::TestCase
  test 'permit resolves type from bullet params and permits type-specific nested attributes' do
    params = ActionController::Parameters.new(
      bullet: {
        body: 'Moody note',
        bulletable_type: 'Note',
        bulletable_attributes: { mood: 'inspired', hacker: 'ignored' }
      }
    )

    permitted = Bullet::Params.permit(params)

    assert_equal 'Moody note', permitted[:body]
    assert_equal 'Note', permitted[:bulletable_type]
    assert_equal 'inspired', permitted.dig(:bulletable_attributes, :mood)
  end

  test 'permit raises when bulletable_type is omitted' do
    params = ActionController::Parameters.new(bullet: { body: 'Quick task' })

    assert_raises(Bullet::Params::TypeRequired) { Bullet::Params.permit(params) }
  end

  test 'permit raises for unknown bulletable type' do
    params = ActionController::Parameters.new(
      bullet: { body: 'Safe', bulletable_type: 'Evil', bulletable_attributes: { mood: 'inspired' } }
    )

    assert_raises(Bullet::Params::TypeRequired) { Bullet::Params.permit(params) }
  end

  test 'preview builds new-bullet defaults from top-level params' do
    day = Date.current.iso8601

    preview = Bullet::Params.preview(
      ActionController::Parameters.new(pops_on: day, bulletable_type: 'Event', bucket_id: '42')
    )

    assert_equal day, preview[:pops_on]
    assert_equal 'Event', preview[:bulletable_type]
    assert_equal '42', preview[:bucket_id]
    assert_equal({}, preview[:bulletable_attributes])
  end

  test 'preview merges explicit defaults' do
    preview = Bullet::Params.preview(
      ActionController::Parameters.new(bulletable_type: 'Task'),
      bucket_id: 99
    )

    assert_equal 99, preview[:bucket_id]
    assert_equal 'Task', preview[:bulletable_type]
  end

  test 'preview omits bulletable_type for invalid type' do
    preview = Bullet::Params.preview(ActionController::Parameters.new(bulletable_type: 'Nope'))

    assert_not preview.key?(:bulletable_type)
  end
end
