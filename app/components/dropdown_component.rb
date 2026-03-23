# frozen_string_literal: true

class DropdownComponent < ViewComponent::Base
  renders_one :trigger

  POSITIONS = {
    bottom_left: 'top-full left-0 mt-2',
    bottom_right: 'top-full right-0 mt-2',
    top_left: 'bottom-full left-0 mb-2',
    top_right: 'bottom-full right-0 mb-2',
    right_end: 'right-0 top-0 translate-x-[calc(100%+0.5rem)]',
    right_bottom: 'right-0 bottom-0 translate-x-[calc(100%+0.5rem)]'
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
        href: item[:href],
        button: item.fetch(:button, false),
        disabled: item.fetch(:disabled, false),
        icon: item[:icon],
        data: item.fetch(:data, {}),
        form_data: item.fetch(:form_data, {}),
        form_options: item.fetch(:form_options, {}),
        method: item[:method],
        tone: item.fetch(:tone, :default).to_sym,
        confirm_label: item[:confirm_label],
        confirm_icon: item[:confirm_icon]
      }
    end
  end

  def item_classes(item)
    [
      'flex w-full items-center gap-2 rounded-xl px-3 py-2 text-sm font-medium whitespace-nowrap transition-all duration-200 ease-out',
      item_tone_classes(item)
    ].join(' ')
  end

  def item_tone_classes(item)
    return 'cursor-default text-emerald-700 bg-emerald-50' if item[:disabled] && item[:tone] == :success
    return 'cursor-not-allowed text-black/40 bg-stone-50' if item[:disabled]
    return 'text-rose-600 hover:bg-rose-50' if item[:tone] == :danger

    'text-black hover:bg-stone-100'
  end

  def item_data(item)
    data = item[:data].dup
    return data if item[:method].blank?

    data.merge(turbo_method: item[:method])
  end

  def item_form_data(item)
    item[:form_data].dup
  end

  def item_form_options(item)
    item[:form_options].dup
  end

  def menu_position_classes
    POSITIONS.fetch(direction)
  end
end
