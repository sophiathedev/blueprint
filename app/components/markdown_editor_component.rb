# frozen_string_literal: true

class MarkdownEditorComponent < ViewComponent::Base
  def initialize(form:, field:, label:, rows: 8, placeholder: nil, hint: nil, **options)
    @form = form
    @field = field
    @label = label
    @rows = rows
    @placeholder = placeholder
    @hint = hint
    @options = options
  end

  private

  attr_reader :form, :field, :label, :rows, :placeholder, :hint, :options

  def wrapper_classes
    ['space-y-2', options[:wrapper_class]].compact.join(' ')
  end

  def tab_base_classes
    'inline-flex items-center justify-center rounded-full px-3 py-1.5 text-sm font-semibold transition'
  end

  def textarea_options
    existing_data = options.fetch(:data, {})

    options.except(:wrapper_class, :data).merge(
      rows: rows,
      placeholder: placeholder,
      class: [
        'h-[clamp(220px,30vh,340px)] min-h-[220px] w-full resize-y border-0 bg-transparent px-4 py-3 pr-28 pb-10 text-sm text-black outline-none transition',
        'focus:outline-none focus:ring-0',
        options[:class]
      ].compact.join(' '),
      data: existing_data.merge(
        action: [existing_data[:action], 'input->markdown-editor#handleInput', 'paste->markdown-editor#handlePaste'].compact.join(' '),
        markdown_editor_target: 'input'
      )
    )
  end
end
