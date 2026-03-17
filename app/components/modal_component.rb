# frozen_string_literal: true

class ModalComponent < ViewComponent::Base
  renders_one :body
  renders_one :footer

  def initialize(title:, description: nil, open: false)
    @title = title
    @description = description
    @open = open
  end

  private

  attr_reader :title, :description

  def open?
    @open
  end
end
