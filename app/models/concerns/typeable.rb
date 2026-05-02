module Typeable
  extend ActiveSupport::Concern

  CARD_TYPES = [
    { title: 'All Bullets', href: '/bullets', icon: 'menu' },
    { title: 'Triage', href: '/triage', icon: 'sparkles' },
    { title: 'Archived', href: '/archived', icon: 'archive' }
  ].freeze
end
