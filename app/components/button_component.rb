# frozen_string_literal: true

class ButtonComponent < ViewComponent::Base
  def initialize(text:)
    @text = text
  end
end
