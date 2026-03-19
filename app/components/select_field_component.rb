# frozen_string_literal: true

class SelectFieldComponent < ViewComponent::Base
  def initialize(form:, field:, label:, choices:, selected: nil, selected_label: nil, prompt: nil, searchable: false, search_placeholder: 'Tìm kiếm...', submit_on_choose: false, show_label: true, full_width: true, trigger_icon: nil, trigger_icon_only_when_selected: false, selected_trigger_class: nil, unselected_trigger_class: nil, options_height_class: nil, **options)
    @form = form
    @field = field
    @label = label
    @choices = choices
    @selected = selected
    @selected_label = selected_label
    @prompt = prompt
    @searchable = searchable
    @search_placeholder = search_placeholder
    @submit_on_choose = submit_on_choose
    @show_label = show_label
    @full_width = full_width
    @trigger_icon = trigger_icon
    @trigger_icon_only_when_selected = trigger_icon_only_when_selected
    @selected_trigger_class = selected_trigger_class
    @unselected_trigger_class = unselected_trigger_class
    @options_height_class = options_height_class
    @options = options
  end

  private

  attr_reader :form, :field, :label, :choices, :selected, :prompt, :search_placeholder, :trigger_icon, :options

  def normalized_choices
    @normalized_choices ||= begin
      base_choices = choices.map do |label, value|
        {
          label: label,
          value: value.to_s,
          selected: selected_value == value.to_s
        }
      end

      if selected_value.present? && base_choices.none? { |choice| choice[:value] == selected_value } && @selected_label.present?
        base_choices.unshift({
          label: @selected_label,
          value: selected_value,
          selected: true
        })
      end

      base_choices
    end
  end

  def selected_value
    @selected_value ||= selected.presence&.to_s || form.object.public_send(field).to_s
  end

  def selected_label
    selected_choice&.fetch(:label) || @selected_label || blank_choice_label || prompt || 'Chọn một giá trị'
  end

  def trigger_classes
    [
      'flex items-center justify-between gap-3 rounded-2xl border border-stone-200 bg-stone-50 px-4 py-2 text-left text-sm text-black outline-none transition',
      'focus:border-primary-400 focus:bg-white focus:ring-4 focus:ring-primary-100',
      ('w-full' if full_width?),
      selected_choice.present? ? @selected_trigger_class : @unselected_trigger_class,
      options[:class]
    ].compact.join(' ')
  end

  def chevron_classes
    [
      'shrink-0',
      selected_choice.present? ? 'text-primary-500' : 'text-black/45'
    ].join(' ')
  end

  def option_classes(choice)
    [
      'flex w-full items-center justify-between gap-3 rounded-xl px-3 py-2 text-sm transition-colors',
      choice[:selected] ? 'bg-primary-50 font-semibold text-primary-800' : 'text-black hover:bg-stone-100'
    ].join(' ')
  end

  def searchable?
    @searchable
  end

  def submit_on_choose?
    @submit_on_choose
  end

  def show_label?
    @show_label
  end

  def full_width?
    @full_width
  end

  def show_trigger_icon?
    return false if trigger_icon.blank?
    return selected_choice.present? if @trigger_icon_only_when_selected

    true
  end

  def options_wrapper_classes
    [
      'overflow-y-auto',
      @options_height_class || (searchable? ? 'h-60' : 'max-h-60')
    ].compact.join(' ')
  end

  def selected_choice
    @selected_choice ||= if selected_value.blank?
      nil
    else
      normalized_choices.find { |choice| choice[:selected] }
    end
  end

  def blank_choice_label
    @blank_choice_label ||= normalized_choices.find { |choice| choice[:value].blank? }&.fetch(:label)
  end
end
