# frozen_string_literal: true

class CheckboxComponent < ViewComponent::Base
  def initialize(form:, attribute:, checked: nil, label: nil, checked_value: '1', unchecked_value: '0', wrapper_class: nil, input_class: nil, label_class: nil, **options)
    @form = form
    @attribute = attribute
    @checked = checked
    @label = label
    @checked_value = checked_value
    @unchecked_value = unchecked_value
    @wrapper_class = wrapper_class
    @input_class = input_class
    @label_class = label_class
    @options = options
  end

  private

  attr_reader :form, :attribute, :label, :checked_value, :unchecked_value, :wrapper_class, :input_class, :label_class, :options

  def checked?
    @checked
  end

  def disabled?
    options[:disabled]
  end

  def checkbox_id
    options[:id] || form.field_id(attribute)
  end

  def wrapper_classes
    [
      'inline-flex items-center gap-2',
      disabled? ? 'opacity-60' : nil,
      wrapper_class
    ].compact.join(' ')
  end

  def checkbox_classes
    [
      'peer sr-only',
      input_class
    ].compact.join(' ')
  end

  def checkbox_options
    options.merge(
      id: checkbox_id,
      checked: checked?,
      class: checkbox_classes
    )
  end

  def visual_label_classes
    [
      'flex h-5 w-5 items-center justify-center rounded-md bg-white text-white transition-all',
      '[&_.checkbox-icon]:opacity-0 peer-checked:[&_.checkbox-icon]:opacity-100',
      'ring-1 ring-inset ring-stone-300 peer-checked:bg-primary-500 peer-checked:ring-primary-500',
      'peer-focus-visible:ring-2 peer-focus-visible:ring-primary-200 peer-focus-visible:ring-offset-2',
      disabled? ? 'cursor-not-allowed' : 'cursor-pointer'
    ].compact.join(' ')
  end

  def label_classes
    [
      'text-sm font-medium text-black',
      label_class
    ].compact.join(' ')
  end
end
