# frozen_string_literal: true

module GoogleSheets
  class TabNameBuilder
    MAX_SHEET_NAME_LENGTH = 100
    INVALID_CHARACTERS = /[\\\/\?\*\[\]:]/

    class << self
      def template_tab_name(service, prefix:)
        build_name(prefix:, kind: 'TPL', service:)
      end

      def aggregate_order_tab_name(prefix:)
        sanitized_prefix = sanitize_segment(prefix.presence || 'Blueprint')
        sanitized_prefix.presence&.first(MAX_SHEET_NAME_LENGTH) || 'Blueprint'
      end

      def order_tab_name(service, prefix:)
        build_order_name(service:)
      end

      private

      def build_name(prefix:, kind:, service:)
        partner_name = sanitize_segment(service.partner.name)
        service_name = sanitize_segment(service.name)
        base_name = [ prefix.presence, "#{kind} - #{partner_name} - #{service_name}", service.id ].compact.join(' | ')
        return base_name if base_name.length <= MAX_SHEET_NAME_LENGTH

        suffix = " | #{service.id}"
        trimmed_base = [ prefix.presence, "#{kind} - #{partner_name} - #{service_name}" ].compact.join(' | ')
        allowed_base_length = MAX_SHEET_NAME_LENGTH - suffix.length

        "#{trimmed_base.first(allowed_base_length).rstrip}#{suffix}"
      end

      def build_order_name(service:)
        partner_name = sanitize_segment(service.partner.name)
        service_name = sanitize_segment(service.name)
        base_name = "#{partner_name} - #{service_name} | #{service.id}"
        return base_name if base_name.length <= MAX_SHEET_NAME_LENGTH

        suffix = " | #{service.id}"
        allowed_base_length = MAX_SHEET_NAME_LENGTH - suffix.length
        trimmed_base = "#{partner_name} - #{service_name}"

        "#{trimmed_base.first(allowed_base_length).rstrip}#{suffix}"
      end

      def sanitize_segment(value)
        value.to_s.gsub(INVALID_CHARACTERS, ' ').squish
      end
    end
  end
end
