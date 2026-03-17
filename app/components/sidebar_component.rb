# frozen_string_literal: true

class SidebarComponent < ViewComponent::Base
  def initialize(brand:, items:)
    @brand = brand
    @items = normalize_items(items)
  end

  private

  attr_reader :brand, :items

  def normalize_items(items)
    items.map do |item|
      {
        label: item.fetch(:label),
        href: item.fetch(:href, '#'),
        active: item.fetch(:active, false),
        badge: item[:badge],
        icon: item.fetch(:icon, 'layout-dashboard')
      }
    end
  end
end
