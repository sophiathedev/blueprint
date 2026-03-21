# frozen_string_literal: true

class DatePickerComponent < ViewComponent::Base
  def initialize(field_id:, input_target:, trigger_label_target:, month_label_target:, days_target:, panel_target:)
    @field_id = field_id
    @input_target = input_target
    @trigger_label_target = trigger_label_target
    @month_label_target = month_label_target
    @days_target = days_target
    @panel_target = panel_target
  end

  private

  attr_reader :field_id, :input_target, :trigger_label_target, :month_label_target, :days_target, :panel_target
end
