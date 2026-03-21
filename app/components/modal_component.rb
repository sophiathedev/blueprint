# frozen_string_literal: true

class ModalComponent < ViewComponent::Base
  renders_one :body
  renders_one :footer

  def initialize(title:, description: nil, open: false, panel_class: nil)
    @title = title
    @description = description
    @open = open
    @panel_class = panel_class
  end

  private

  attr_reader :title, :description, :panel_class

  def open?
    @open
  end
end
