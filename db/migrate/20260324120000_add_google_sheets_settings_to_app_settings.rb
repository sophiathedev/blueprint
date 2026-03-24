# frozen_string_literal: true

class AddGoogleSheetsSettingsToAppSettings < ActiveRecord::Migration[8.1]
  def change
    change_table :app_settings, bulk: true do |t|
      t.boolean :google_sheets_enabled, null: false, default: false
      t.string :google_sheets_spreadsheet_id
      t.string :google_sheets_tab_prefix
      t.integer :google_sheets_sync_interval_value
      t.integer :google_sheets_sync_interval_unit
      t.datetime :google_sheets_last_synced_at
      t.string :google_sheets_last_sync_status
      t.text :google_sheets_last_sync_error
      t.string :google_sheets_next_sync_job_id
      t.datetime :google_sheets_next_sync_at
    end
  end
end
