# frozen_string_literal: true

class DropdownComponent < ViewComponent::Base
  renders_one :trigger

  POSITIONS = {
    bottom_left: 'top-full left-0 mt-2',
    bottom_right: 'top-full right-0 mt-2',
    top_left: 'bottom-full left-0 mb-2',
    top_right: 'bottom-full right-0 mb-2',
    right_end: 'right-0 top-0 translate-x-[calc(100%+0.5rem)]'
  }.freeze

  def initialize(items:, direction: :top_left)
    @items = normalize_items(items)
    @direction = direction.to_sym
  end

  private

  attr_reader :items, :direction

  def normalize_items(items)
    items.map do |item|
      {
        label: item.fetch(:label),
        href: item.fetch(:href),
        icon: item[:icon],
        method: item[:method],
        tone: item.fetch(:tone, :default).to_sym
      }
    end
  end

  def item_classes(item)
    [
      'flex w-full items-center gap-2 rounded-xl px-3 py-2 text-sm font-medium transition-colors',
      item[:tone] == :danger ? 'text-rose-600 hover:bg-rose-50' : 'text-black hover:bg-stone-100'
    ].join(' ')
  end

  def item_data(item)
    return {} if item[:method].blank?

    { turbo_method: item[:method] }
  end

  def menu_position_classes
    POSITIONS.fetch(direction)
  end
end
