# frozen_string_literal: true

class ButtonComponent < ViewComponent::Base
  TYPES = %i[button submit navigate icon].freeze
  VARIANTS = %i[primary secondary].freeze

  def initialize(label:, type:, variant: :secondary, href: nil, icon: nil, full_width: false, **options)
    @label = label
    @type = type.to_sym
    @variant = variant.to_sym
    @href = href
    @icon = icon
    @full_width = full_width
    @options = options
    validate!
  end

  private

  attr_reader :label, :type, :variant, :href, :icon, :options

  def validate!
    raise ArgumentError, "Unknown button type: #{type}" unless TYPES.include?(type)
    raise ArgumentError, "Unknown button variant: #{variant}" unless VARIANTS.include?(variant)
    raise ArgumentError, 'href is required for navigate buttons' if navigate? && href.blank?
    raise ArgumentError, 'icon is required for icon buttons' if icon_button? && icon.blank?
  end

  def navigate?
    type == :navigate
  end

  def icon_button?
    type == :icon
  end

  def html_button_type
    type == :submit ? :submit : :button
  end

  def button_classes
    return icon_button_classes if icon_button?

    [
      'inline-flex items-center justify-center gap-2 rounded-2xl border px-3 py-2.5 text-sm font-semibold transition-colors',
      'focus:outline-none focus:ring-2 focus:ring-primary-200 focus:ring-offset-2',
      full_width? ? 'w-full' : nil,
      variant_classes,
      options[:class]
    ].compact.join(' ')
  end

  def icon_button_classes
    [
      'inline-flex h-9 w-9 items-center justify-center rounded-full border-0 bg-transparent text-black/60 transition-colors',
      'focus:outline-none focus:ring-2 focus:ring-primary-200 focus:ring-offset-2',
      'hover:bg-stone-100 hover:text-black/85',
      options[:class]
    ].compact.join(' ')
  end

  def variant_classes
    case variant
    when :primary
      'border-primary-500 bg-primary-500 text-white hover:bg-primary-600 hover:border-primary-600'
    when :secondary
      'border-stone-200 bg-stone-100 text-black hover:bg-stone-200 hover:border-stone-300'
    end
  end

  def html_options
    attrs = options.except(:class)
    attrs[:'aria-label'] ||= label if icon_button?
    attrs.merge(class: button_classes)
  end

  def full_width?
    @full_width
  end
end
