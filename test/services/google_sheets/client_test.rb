# frozen_string_literal: true

require 'test_helper'

class GoogleSheetsClientTest < ActiveSupport::TestCase
  test 'creates public writer permission when workbook has no anyone permission' do
    client = GoogleSheets::Client.new(client_id: 'client', client_secret: 'secret', refresh_token: 'refresh')
    created = []

    client.stub(:file_permissions, { 'permissions' => [] }) do
      client.stub(:create_file_permission, ->(spreadsheet_id, payload) { created << [spreadsheet_id, payload] }) do
        client.stub(:update_file_permission, ->(*) { flunk 'should not update existing permission' }) do
          client.ensure_anyone_with_link_can_edit('sheet-1')
        end
      end
    end

    assert_equal [
      [
        'sheet-1',
        { type: 'anyone', role: 'writer', allowFileDiscovery: false }
      ]
    ], created
  end

  test 'updates public permission when workbook is not already link-editable' do
    client = GoogleSheets::Client.new(client_id: 'client', client_secret: 'secret', refresh_token: 'refresh')
    updated = []

    client.stub(:file_permissions, {
      'permissions' => [
        { 'id' => 'perm-1', 'type' => 'anyone', 'role' => 'reader', 'allowFileDiscovery' => true }
      ]
    }) do
      client.stub(:create_file_permission, ->(*) { flunk 'should not create a new permission' }) do
        client.stub(:update_file_permission, ->(spreadsheet_id, permission_id, payload) { updated << [spreadsheet_id, permission_id, payload] }) do
          client.ensure_anyone_with_link_can_edit('sheet-2')
        end
      end
    end

    assert_equal [
      [
        'sheet-2',
        'perm-1',
        { role: 'writer', allowFileDiscovery: false }
      ]
    ], updated
  end

  test 'skips permission changes when workbook is already link-editable' do
    client = GoogleSheets::Client.new(client_id: 'client', client_secret: 'secret', refresh_token: 'refresh')

    client.stub(:file_permissions, {
      'permissions' => [
        { 'id' => 'perm-1', 'type' => 'anyone', 'role' => 'writer', 'allowFileDiscovery' => false }
      ]
    }) do
      client.stub(:create_file_permission, ->(*) { flunk 'should not create a permission' }) do
        client.stub(:update_file_permission, ->(*) { flunk 'should not update a permission' }) do
          client.ensure_anyone_with_link_can_edit('sheet-3')
        end
      end
    end
  end
end
