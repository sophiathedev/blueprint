# frozen_string_literal: true

require 'test_helper'

class SidebarComponentTest < ViewComponent::TestCase
  def test_renders_flat_sidebar_navigation
    render_inline(
      SidebarComponent.new(
        brand: 'Blueprint',
        caption: 'Flat navigation',
        items: [
          { label: 'Dashboard', href: '#', active: true },
          { label: 'Projects', href: '#', badge: '12' }
        ]
      )
    )

    assert_selector 'aside'
    assert_text 'Blueprint'
    assert_text 'Dashboard'
    assert_text 'Projects'
    assert_text 'Đăng nhập'
    assert_text 'Đăng ký'
  end
end
