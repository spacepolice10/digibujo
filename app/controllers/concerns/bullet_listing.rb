# frozen_string_literal: true

module BulletListing
  extend ActiveSupport::Concern

  private

  def set_bullet_listing(context, per_page: [ 5, 15, 30, 50 ])
    @listing = Bullet::Listing.for(user: Current.user, context: context, params: params)
    @bullets = set_page_and_extract_portion_from(@listing.relation, per_page: per_page)
  end
end
