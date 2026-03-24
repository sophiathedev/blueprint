# frozen_string_literal: true

require 'test_helper'

class GoogleSheetsTabNameBuilderTest < ActiveSupport::TestCase
  test 'builds sanitized names within google sheets limit' do
    partner = Partner.create!(name: 'Partner / Invalid')
    service = partner.services.create!(name: 'Service Name With A Very Long Title ' * 4)

    template_title = GoogleSheets::TabNameBuilder.template_tab_name(service, prefix: 'Blueprint')
    order_title = GoogleSheets::TabNameBuilder.order_tab_name(service, prefix: 'Blueprint')

    assert_operator template_title.length, :<=, GoogleSheets::TabNameBuilder::MAX_SHEET_NAME_LENGTH
    assert_operator order_title.length, :<=, GoogleSheets::TabNameBuilder::MAX_SHEET_NAME_LENGTH
    assert_no_match(/[\\\/\?\*\[\]:]/, template_title)
    assert_no_match(/[\\\/\?\*\[\]:]/, order_title)
    assert_no_match(/\ABlueprint \| ORD/, order_title)
  end
end
