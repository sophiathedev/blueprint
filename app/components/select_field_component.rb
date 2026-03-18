# frozen_string_literal: true

class SelectFieldComponent < ViewComponent::Base
  def initialize(form:, field:, label:, choices:, selected: nil, prompt: nil, **options)
    @form = form
    @field = field
    @label = label
    @choices = choices
    @selected = selected
    @prompt = prompt
    @options = options
  end

  private

  attr_reader :form, :field, :label, :choices, :selected, :prompt, :options

  def normalized_choices
    @normalized_choices ||= choices.map do |label, value|
      {
        label: label,
        value: value.to_s,
        selected: selected_value == value.to_s
      }
    end
  end

  def selected_value
    @selected_value ||= selected.presence || form.object.public_send(field).to_s
  end

  def selected_label
    normalized_choices.find { |choice| choice[:selected] }&.fetch(:label) || prompt || 'Chọn một giá trị'
  end

  def trigger_classes
    [
      'flex w-full items-center justify-between gap-3 rounded-2xl border border-stone-200 bg-stone-50 px-4 py-2 text-left text-sm text-black outline-none transition',
      'focus:border-primary-400 focus:bg-white focus:ring-4 focus:ring-primary-100',
      options[:class]
    ].compact.join(' ')
  end

  def option_classes(choice)
    [
      'flex w-full items-center justify-between gap-3 rounded-xl px-3 py-2 text-sm transition-colors',
      choice[:selected] ? 'bg-primary-50 font-semibold text-primary-800' : 'text-black hover:bg-stone-100'
    ].join(' ')
  end
end
