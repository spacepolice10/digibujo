# frozen_string_literal: true

class BulletCreator
  attr_reader :bullet

  def initialize(user, params)
    @user = user
    @params = params
  end

  def call
    build_bullet
    if @bullet.save
      BulletContentFinalizer.call(@bullet, bulletable_attributes: @params[:bulletable_attributes])
    end
    self
  end

  def success?
    @bullet.errors.none?
  end

  def build
    build_bullet
    self
  end

  private

  def build_bullet
    type_name = @params[:bulletable_type].presence || Bullet::Composer.default_type
    attributes = @params.except(:bulletable_type, :bulletable_attributes, :composer_id)
    @bullet = @user.bullets.new(attributes.merge(bulletable: type_name.constantize.new))
  end
end
