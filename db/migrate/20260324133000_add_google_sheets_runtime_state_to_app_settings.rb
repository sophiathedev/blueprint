# frozen_string_literal: true

class AddGoogleSheetsRuntimeStateToAppSettings < ActiveRecord::Migration[8.1]
  def change
    change_table :app_settings, bulk: true do |t|
      t.boolean :google_sheets_cancel_requested, null: false, default: false
      t.string :google_sheets_current_job_id
      t.integer :google_sheets_sync_progress, null: false, default: 0
    end
  end
end
