# frozen_string_literal: true

module GoogleSheets
  class WorkbookSyncService
    class CancelledError < StandardError; end

    MANAGED_KINDS = %w[TPL ORD].freeze
    BATCH_UPDATE_CHUNK_SIZE = 25

    def initialize(setting: AppSetting.current, client: Client.new)
      @setting = setting
      @client = client
      @completed_steps = 0
      @total_steps = 1
    end

    def call
      spreadsheet_id = ensure_accessible_spreadsheet_id!
      sync_spreadsheet_title!(spreadsheet_id)
      metadata = client.spreadsheet_metadata(spreadsheet_id)
      existing_sheets = metadata.fetch('sheets', []).to_h do |sheet|
        properties = sheet.fetch('properties', {})
        [properties['title'], properties]
      end

      desired_tabs = build_desired_tabs
      initialize_progress!(existing_sheets, desired_tabs)
      advance_progress!

      ensure_sheets_exist!(spreadsheet_id, existing_sheets, desired_tabs)
      cleanup_stale_managed_sheets!(existing_sheets, desired_tabs.keys)
      resize_existing_sheets!(spreadsheet_id, existing_sheets, desired_tabs)

      desired_tabs.each do |title, values|
        abort_if_cancel_requested!
        client.clear_values(spreadsheet_id, "#{quoted_title(title)}!A:Z")
        advance_progress!
        abort_if_cancel_requested!
        client.update_values(spreadsheet_id, "#{quoted_title(title)}!A1", values)
        advance_progress!
      end
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

    def ensure_sheets_exist!(spreadsheet_id, existing_sheets, desired_tabs)
      new_titles = desired_tabs.keys - existing_sheets.keys
      return if new_titles.empty?

      requests = new_titles.map do |title|
        values = desired_tabs.fetch(title)
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

    def cleanup_stale_managed_sheets!(existing_sheets, desired_titles)
      stale_titles = existing_sheets.keys.select do |title|
        managed_title?(title) && !desired_titles.include?(title)
      end
      return if stale_titles.empty?

      requests = stale_titles.map do |title|
        { deleteSheet: { sheetId: existing_sheets.fetch(title).fetch('sheetId') } }
      end

      batch_update_in_chunks(setting.google_sheets_spreadsheet_id, requests)
    end

    def resize_existing_sheets!(spreadsheet_id, existing_sheets, desired_tabs)
      requests = desired_tabs.filter_map do |title, values|
        properties = existing_sheets[title]
        next if properties.blank?

        grid_properties = grid_properties_for(values)
        current_grid = properties.fetch('gridProperties', {})
        next if current_grid['rowCount'] == grid_properties[:rowCount] &&
                current_grid['columnCount'] == grid_properties[:columnCount]

        {
          updateSheetProperties: {
            properties: {
              sheetId: properties.fetch('sheetId'),
              gridProperties: grid_properties
            },
            fields: 'gridProperties.rowCount,gridProperties.columnCount'
          }
        }
      end

      return if requests.empty?

      batch_update_in_chunks(spreadsheet_id, requests)
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

    def managed_title?(title)
      MANAGED_KINDS.any? do |kind|
        title.start_with?("#{kind} -") || title.include?(" | #{kind} -")
      end
    end

    def batch_update_in_chunks(spreadsheet_id, requests)
      requests.each_slice(BATCH_UPDATE_CHUNK_SIZE) do |request_chunk|
        abort_if_cancel_requested!
        client.batch_update(spreadsheet_id, request_chunk)
        advance_progress!
      end
    end

    def initialize_progress!(existing_sheets, desired_tabs)
      add_chunks = chunk_count(desired_tabs.keys - existing_sheets.keys)
      stale_titles = existing_sheets.keys.select { |title| managed_title?(title) && !desired_tabs.keys.include?(title) }
      delete_chunks = chunk_count(stale_titles)
      resize_requests = desired_tabs.count do |title, values|
        properties = existing_sheets[title]
        next false if properties.blank?

        grid_properties = grid_properties_for(values)
        current_grid = properties.fetch('gridProperties', {})
        current_grid['rowCount'] != grid_properties[:rowCount] || current_grid['columnCount'] != grid_properties[:columnCount]
      end

      @total_steps = [
        1 + add_chunks + delete_chunks + chunk_count(Array.new(resize_requests)) + (desired_tabs.size * 2),
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

    def recreate_spreadsheet!
      response = client.create_spreadsheet(title: default_spreadsheet_title)
      spreadsheet_id = response['spreadsheetId'].to_s
      raise Client::Error, 'Google Sheets không trả về spreadsheet ID sau khi tạo lại workbook.' if spreadsheet_id.blank?

      setting.update!(google_sheets_spreadsheet_id: spreadsheet_id)
      spreadsheet_id
    end
  end
end
