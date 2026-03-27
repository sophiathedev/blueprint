# frozen_string_literal: true

require 'securerandom'

module GoogleSheets
  class WorkbookSyncService
    class CancelledError < StandardError; end

    BATCH_UPDATE_CHUNK_SIZE = 25
    EMPTY_STATE_CELL_VALUE = 'Chưa có dữ liệu order để sync.'.freeze

    def initialize(setting: AppSetting.current, client: Client.new)
      @setting = setting
      @client = client
      @completed_steps = 0
      @total_steps = 1
    end

    def call
      spreadsheet_id = ensure_accessible_spreadsheet_id!
      ensure_spreadsheet_sharing!(spreadsheet_id)
      sync_spreadsheet_title!(spreadsheet_id)
      metadata = client.spreadsheet_metadata(spreadsheet_id)
      existing_sheets = metadata.fetch('sheets', []).to_h do |sheet|
        properties = sheet.fetch('properties', {})
        [properties['title'], properties]
      end

      desired_tabs = build_desired_tabs
      sync_tabs = normalized_tabs_for_sync(desired_tabs)
      initialize_progress!(existing_sheets, sync_tabs)
      advance_progress!

      temporary_sheet_title = create_temporary_sheet!(spreadsheet_id)
      delete_sheets!(spreadsheet_id, existing_sheets.values)
      create_sheets!(spreadsheet_id, sync_tabs)

      sync_tabs.each do |title, values|
        abort_if_cancel_requested!
        client.clear_values(spreadsheet_id, "#{quoted_title(title)}!A:Z")
        advance_progress!
        abort_if_cancel_requested!
        client.update_values(spreadsheet_id, "#{quoted_title(title)}!A1", values)
        advance_progress!
      end

      temporary_sheet = sheet_properties_for(spreadsheet_id, temporary_sheet_title)
      delete_sheets!(spreadsheet_id, [temporary_sheet]) if temporary_sheet.present?
    end

    private

    attr_reader :setting, :client

    def build_desired_tabs
      services.each_with_object({}) do |service, tabs|
        snapshot = ServiceSnapshotBuilder.new(service)
        next unless snapshot.has_order_rows?

        tabs[TabNameBuilder.order_tab_name(service, prefix: setting.google_sheets_tab_prefix)] = snapshot.order_rows
      end
    end

    def services
      @services ||= Service.includes(:partner, order_services: { order_tasks: { task: :member } })
                           .order(:id)
                           .to_a
    end

    def normalized_tabs_for_sync(desired_tabs)
      return desired_tabs if desired_tabs.present?

      { empty_state_tab_title => [[EMPTY_STATE_CELL_VALUE]] }
    end

    def empty_state_tab_title
      [setting.google_sheets_tab_prefix.presence || 'Blueprint', 'Không có dữ liệu']
        .join(' | ')
        .first(TabNameBuilder::MAX_SHEET_NAME_LENGTH)
    end

    def create_temporary_sheet!(spreadsheet_id)
      title = "__BLUEPRINT_SYNC_TMP__#{SecureRandom.hex(4)}"
      create_sheets!(spreadsheet_id, { title => [[nil]] })
      title
    end

    def create_sheets!(spreadsheet_id, tabs)
      return if tabs.empty?

      requests = tabs.map do |title, values|
        {
          addSheet: {
            properties: {
              title: title,
              gridProperties: grid_properties_for(values)
            }
          }
        }
      end

      batch_update_in_chunks(spreadsheet_id, requests)
    end

    def delete_sheets!(spreadsheet_id, sheets)
      valid_sheets = Array(sheets).compact
      return if valid_sheets.empty?

      requests = valid_sheets.map do |properties|
        { deleteSheet: { sheetId: properties.fetch('sheetId') } }
      end

      batch_update_in_chunks(spreadsheet_id, requests)
    end

    def sheet_properties_for(spreadsheet_id, title)
      client.spreadsheet_metadata(spreadsheet_id)
            .fetch('sheets', [])
            .map { |sheet| sheet.fetch('properties', {}) }
            .find { |properties| properties['title'] == title }
    end

    def ensure_spreadsheet_id!
      abort_if_cancel_requested!

      spreadsheet_id = setting.google_sheets_spreadsheet_id
      return spreadsheet_id if spreadsheet_id.present?

      response = client.create_spreadsheet(title: default_spreadsheet_title)
      spreadsheet_id = response['spreadsheetId'].to_s
      raise Client::Error, 'Google Sheets không trả về spreadsheet ID sau khi tạo workbook.' if spreadsheet_id.blank?

      setting.update!(google_sheets_spreadsheet_id: spreadsheet_id)
      spreadsheet_id
    end

    def ensure_accessible_spreadsheet_id!
      spreadsheet_id = ensure_spreadsheet_id!
      file_metadata = client.file_metadata(spreadsheet_id)
      raise GoogleSheets::Client::NotFoundError, 'Spreadsheet hiện đang ở trong thùng rác trên Google Drive.' if file_metadata['trashed']

      client.spreadsheet_metadata(spreadsheet_id)
      spreadsheet_id
    rescue GoogleSheets::Client::NotFoundError
      recreate_spreadsheet!
    end

    def default_spreadsheet_title
      "blueprint-#{Time.current.in_time_zone('Asia/Ho_Chi_Minh').strftime('%H-%M-%S-%d%m%Y')}"
    end

    def grid_properties_for(values)
      row_count = [values.size, 1].max
      column_count = [values.map(&:size).max.to_i, 1].max

      {
        rowCount: row_count,
        columnCount: column_count
      }
    end

    def batch_update_in_chunks(spreadsheet_id, requests)
      requests.each_slice(BATCH_UPDATE_CHUNK_SIZE) do |request_chunk|
        abort_if_cancel_requested!
        client.batch_update(spreadsheet_id, request_chunk)
        advance_progress!
      end
    end

    def initialize_progress!(existing_sheets, sync_tabs)
      temp_add_chunks = 1
      delete_chunks = chunk_count(existing_sheets.values)
      add_chunks = chunk_count(sync_tabs.keys)
      temp_delete_chunks = 1
      @total_steps = [
        1 + temp_add_chunks + delete_chunks + add_chunks + (sync_tabs.size * 2) + temp_delete_chunks,
        1
      ].max
      setting.update_google_sheets_progress!(0)
    end

    def chunk_count(items)
      items.each_slice(BATCH_UPDATE_CHUNK_SIZE).count
    end

    def advance_progress!
      @completed_steps += 1
      progress = ((@completed_steps.to_f / @total_steps) * 100).round
      setting.update_google_sheets_progress!(progress)
    end

    def abort_if_cancel_requested!
      raise CancelledError, 'Đã hủy sync Google Sheets theo yêu cầu.' if setting.reload.google_sheets_cancel_requested?
    end

    def quoted_title(title)
      "'#{title.to_s.gsub("'", "''")}'"
    end

    def sync_spreadsheet_title!(spreadsheet_id)
      abort_if_cancel_requested!
      client.update_spreadsheet_title(spreadsheet_id, title: default_spreadsheet_title)
    end

    def ensure_spreadsheet_sharing!(spreadsheet_id)
      abort_if_cancel_requested!
      client.ensure_anyone_with_link_can_edit(spreadsheet_id)
    end

    def recreate_spreadsheet!
      response = client.create_spreadsheet(title: default_spreadsheet_title)
      spreadsheet_id = response['spreadsheetId'].to_s
      raise Client::Error, 'Google Sheets không trả về spreadsheet ID sau khi tạo lại workbook.' if spreadsheet_id.blank?

      setting.update!(google_sheets_spreadsheet_id: spreadsheet_id)
      spreadsheet_id
    end
  end
end
