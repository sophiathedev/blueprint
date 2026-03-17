# frozen_string_literal: true

require 'test_helper'

class ButtonComponentTest < ViewComponent::TestCase
  def test_renders_navigate_button_with_icon
    render_inline(
      ButtonComponent.new(
        label: 'Dang nhap',
        type: :navigate,
        variant: :secondary,
        href: '/login',
        icon: 'log-in',
        full_width: true
      )
    )

    assert_selector 'a[href="/login"]', text: 'Dang nhap'
    assert_selector 'svg'
  end

  def test_renders_submit_button
    render_inline(
      ButtonComponent.new(
        label: 'Dang ky',
        type: :submit,
        variant: :primary,
        icon: 'user-plus'
      )
    )

    assert_selector 'button[type="submit"]', text: 'Dang ky'
  end

  def test_renders_icon_button
    render_inline(
      ButtonComponent.new(
        label: 'Collapse sidebar',
        type: :icon,
        icon: 'panel-left-close'
      )
    )

    assert_selector 'button[aria-label="Collapse sidebar"]'
    assert_selector 'svg'
  end
end
