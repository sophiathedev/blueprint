# frozen_string_literal: true

require 'erb'
require 'json'
require 'net/http'
require 'uri'

module GoogleSheets
  class Client
    class Error < StandardError; end
    class NotFoundError < Error; end
    class RetriableError < Error; end

    OAUTH_TOKEN_URL = 'https://oauth2.googleapis.com/token'
    SHEETS_API_BASE_URL = 'https://sheets.googleapis.com/v4/spreadsheets'
    OPEN_TIMEOUT = 10
    READ_TIMEOUT = 45
    WRITE_TIMEOUT = 45
    MAX_RETRIES = 2
    RETRIABLE_ERRORS = [
      Net::OpenTimeout,
      Net::ReadTimeout,
      Errno::ECONNRESET,
      Errno::ETIMEDOUT,
      EOFError,
      IOError,
      SocketError
    ].freeze
    RETRIABLE_HTTP_CODES = %w[429 500 502 503 504].freeze

    def initialize(
      client_id: ENV['GOOGLE_OAUTH_CLIENT_ID'],
      client_secret: ENV['GOOGLE_OAUTH_CLIENT_SECRET'],
      refresh_token: ENV['GOOGLE_OAUTH_REFRESH_TOKEN']
    )
      @client_id = client_id.to_s
      @client_secret = client_secret.to_s
      @refresh_token = refresh_token.to_s
    end

    def spreadsheet_metadata(spreadsheet_id)
      get_json("#{SHEETS_API_BASE_URL}/#{spreadsheet_id}?fields=sheets.properties(sheetId,title,gridProperties.rowCount,gridProperties.columnCount)")
    end

    def create_spreadsheet(title:)
      post_json(SHEETS_API_BASE_URL, {
        properties: {
          title: title
        }
      })
    end

    def update_spreadsheet_title(spreadsheet_id, title:)
      batch_update(spreadsheet_id, [
        {
          updateSpreadsheetProperties: {
            properties: { title: title },
            fields: 'title'
          }
        }
      ])
    end

    def batch_update(spreadsheet_id, requests)
      post_json("#{SHEETS_API_BASE_URL}/#{spreadsheet_id}:batchUpdate", { requests: requests })
    end

    def clear_values(spreadsheet_id, range)
      post_json("#{SHEETS_API_BASE_URL}/#{spreadsheet_id}/values/#{escape_range(range)}:clear", {})
    end

    def update_values(spreadsheet_id, range, values)
      put_json(
        "#{SHEETS_API_BASE_URL}/#{spreadsheet_id}/values/#{escape_range(range)}?valueInputOption=RAW",
        { range: range, majorDimension: 'ROWS', values: values }
      )
    end

    private

    attr_reader :client_id, :client_secret, :refresh_token

    def access_token
      raise Error, 'Thiếu cấu hình Google OAuth ENV.' if [client_id, client_secret, refresh_token].any?(&:blank?)

      response = post_form(OAUTH_TOKEN_URL, {
        client_id:,
        client_secret:,
        refresh_token:,
        grant_type: 'refresh_token'
      })
      token = JSON.parse(response.body)['access_token']
      raise Error, 'Không lấy được access token từ Google OAuth.' if token.blank?

      token
    rescue JSON::ParserError => e
      raise Error, "Google OAuth trả về dữ liệu không hợp lệ: #{e.message}"
    end

    def get_json(url)
      uri = URI(url)
      request_json(uri, Net::HTTP::Get.new(uri))
    end

    def post_json(url, payload)
      uri = URI(url)
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request.body = JSON.generate(payload)
      request_json(uri, request)
    end

    def put_json(url, payload)
      uri = URI(url)
      request = Net::HTTP::Put.new(uri)
      request['Content-Type'] = 'application/json'
      request.body = JSON.generate(payload)
      request_json(uri, request)
    end

    def post_form(url, payload)
      uri = URI(url)
      request = Net::HTTP::Post.new(uri)
      request.set_form_data(payload)
      perform_http_request(uri, request)
    end

    def request_json(uri, request)
      request['Authorization'] = "Bearer #{access_token}"
      request['Accept'] = 'application/json'

      response = perform_http_request(uri, request)
      JSON.parse(response.body)
    rescue JSON::ParserError => e
      raise Error, "Google Sheets trả về dữ liệu không hợp lệ: #{e.message}"
    end

    def perform_http_request(uri, request)
      with_retries do
        Net::HTTP.start(
          uri.host,
          uri.port,
          use_ssl: uri.scheme == 'https',
          open_timeout: OPEN_TIMEOUT,
          read_timeout: READ_TIMEOUT,
          write_timeout: WRITE_TIMEOUT
        ) do |http|
          response = http.request(request)
          return response if response.is_a?(Net::HTTPSuccess)

          body = response.body.to_s
          parsed_message = JSON.parse(body).dig('error', 'message')
          error_message = parsed_message.presence || "Google API lỗi HTTP #{response.code}"

          raise NotFoundError, error_message if response.code == '404'

          if RETRIABLE_HTTP_CODES.include?(response.code)
            raise RetriableError, error_message
          end

          raise Error, error_message
        rescue JSON::ParserError
          error_message = "Google API lỗi HTTP #{response.code}"
          raise NotFoundError, error_message if response.code == '404'
          raise RetriableError, error_message if RETRIABLE_HTTP_CODES.include?(response.code)

          raise Error, error_message
        end
      end
    rescue StandardError => e
      raise e if e.is_a?(Error)

      raise Error, e.message
    end

    def escape_range(range)
      ERB::Util.url_encode(range)
    end

    def with_retries
      attempts = 0

      begin
        attempts += 1
        yield
      rescue *RETRIABLE_ERRORS, RetriableError => e
        raise Error, "Google API tạm thời lỗi sau #{attempts} lần thử: #{e.message}" if attempts > MAX_RETRIES

        sleep(0.5 * attempts)
        retry
      end
    end
  end
end
