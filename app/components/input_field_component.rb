# frozen_string_literal: true

class InputFieldComponent < ViewComponent::Base
  TYPES = %i[email password text].freeze

  def initialize(form:, field:, label:, type: :text, value: nil, **options)
    @form = form
    @field = field
    @label = label
    @type = type.to_sym
    @value = value
    @options = options
    validate!
  end

  private

  attr_reader :form, :field, :label, :type, :value, :options

  def validate!
    raise ArgumentError, "Unknown input type: #{type}" unless TYPES.include?(type)
  end

  def field_method
    "#{type}_field"
  end

  def input_options
    existing_data = options.fetch(:data, {})
    merged_options = options.merge(
      class: [
        'w-full rounded-2xl border border-stone-200 bg-stone-50 px-4 py-2 pr-10 text-sm text-black outline-none transition',
        'focus:border-primary-400 focus:bg-white focus:ring-4 focus:ring-primary-100',
        options[:class]
      ].compact.join(' '),
      data: existing_data
    )

    return merged_options if value.nil?

    merged_options.merge(value: value)
  end
end
