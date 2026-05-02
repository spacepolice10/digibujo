class Bullets::FieldsController < ApplicationController
  def show
    bulletable_type = params[:id].to_s.classify
    unless Bullet.bulletable_types.include?(bulletable_type)
      return head :not_found
    end

    @bullet = Bullet.new(bulletable: bulletable_type.constantize.new)
  end
end
