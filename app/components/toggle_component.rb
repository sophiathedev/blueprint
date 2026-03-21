# frozen_string_literal: true

class ToggleComponent < ViewComponent::Base
  def initialize(id:, name:, label:, description: nil, checked: false, disabled: false, wrapper_class: nil, content_class: nil, switch_wrapper_class: nil, input_data: {}, **options)
    @id = id
    @name = name
    @label = label
    @description = description
    @checked = checked
    @disabled = disabled
    @wrapper_class = wrapper_class
    @content_class = content_class
    @switch_wrapper_class = switch_wrapper_class
    @input_data = input_data
    @options = options
  end

  private

  attr_reader :id, :name, :label, :description, :wrapper_class, :content_class, :switch_wrapper_class, :input_data, :options

  def checked?
    @checked
  end

  def disabled?
    @disabled
  end

  def wrapper_classes
    [
      "flex w-full items-center justify-between gap-4 rounded-[24px] border border-stone-200 bg-white px-4 py-3 transition",
      disabled? ? "opacity-60" : "hover:border-stone-300",
      wrapper_class
    ].compact.join(" ")
  end

  def checkbox_classes
    [
      "peer sr-only",
      options[:class]
    ].compact.join(" ")
  end

  def input_options
    options.except(:class).merge(
      id: id,
      name: name,
      type: "checkbox",
      checked: checked?,
      disabled: disabled?,
      class: checkbox_classes,
      data: input_data
    )
  end

  def content_classes
    ["min-w-0 flex-1", content_class].compact.join(" ")
  end

  def switch_classes
    ["ml-auto shrink-0", switch_wrapper_class].compact.join(" ")
  end
end
