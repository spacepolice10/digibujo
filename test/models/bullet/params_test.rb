# frozen_string_literal: true

require 'test_helper'

class Bullet::ParamsTest < ActiveSupport::TestCase
  test 'permit resolves type from bullet params and permits type-specific nested attributes' do
    params = ActionController::Parameters.new(
      bullet: {
        bulletable_type: 'Note',
        bulletable_attributes: { body: 'Moody note', mood: 'inspired', hacker: 'ignored' }
      }
    )

    permitted = Bullet::Params.permit(params)

    assert_equal 'Moody note', permitted.dig(:bulletable_attributes, :body)
    assert_equal 'Note', permitted[:bulletable_type]
    assert_equal 'inspired', permitted.dig(:bulletable_attributes, :mood)
    assert_nil permitted.dig(:bulletable_attributes, :hacker)
  end

  test 'permit raises when bulletable_type is omitted' do
    params = ActionController::Parameters.new(bullet: { bulletable_attributes: { body: 'Quick task' } })

    assert_raises(Bullet::Params::TypeRequired) { Bullet::Params.permit(params) }
  end

  test 'permit raises for unknown bulletable type' do
    params = ActionController::Parameters.new(
      bullet: { bulletable_type: 'Evil', bulletable_attributes: { body: 'Safe', mood: 'inspired' } }
    )

    assert_raises(Bullet::Params::TypeRequired) { Bullet::Params.permit(params) }
  end

  test 'resolve_type accepts valid bulletable type names' do
    assert_equal 'Task', Bullet::Params.resolve_type('Task')
    assert_nil Bullet::Params.resolve_type('Nope')
  end
end
