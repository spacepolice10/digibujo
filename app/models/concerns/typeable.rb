module Typeable
  extend ActiveSupport::Concern

  CARD_TYPES = [
    { title: 'All Cards', href: '/cards', icon: 'menu' },
    { title: 'Triage', href: '/triage', icon: 'sparkles' },
    { title: 'Archived', href: '/archived', icon: 'archive' }
  ].freeze
end
