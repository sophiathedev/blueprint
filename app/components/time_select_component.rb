# frozen_string_literal: true

class TimeSelectComponent < ViewComponent::Base
  def initialize(hour_id:, minute_id:, hour_target:, minute_target:, hidden: true)
    @hour_id = hour_id
    @minute_id = minute_id
    @hour_target = hour_target
    @minute_target = minute_target
    @hidden = hidden
  end

  private

  attr_reader :hour_id, :minute_id, :hour_target, :minute_target

  def hidden?
    @hidden
  end
end
