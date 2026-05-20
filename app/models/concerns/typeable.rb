module Typeable
  extend ActiveSupport::Concern

  CARD_TYPES = [
    { title: 'All Bullets', href: '/bullets', icon: 'menu' },
    { title: 'Pinned', href: '/pinned', icon: 'pin' },
    { title: 'Archived', href: '/archived', icon: 'archive' }
  ].freeze
end
