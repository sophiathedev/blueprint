# frozen_string_literal: true

module Admin
  class MarkdownAttachmentsController < BaseController
    include AssetsUrlBuilder

    def create
      uploaded_file = params.require(:attachment)

      blob = ActiveStorage::Blob.create_and_upload!(
        io: uploaded_file.tempfile.tap(&:rewind),
        filename: uploaded_file.original_filename.presence || default_filename,
        content_type: uploaded_file.content_type.presence || 'application/octet-stream'
      )

      render json: serialize_attachment(blob), status: :created
    rescue ActionController::ParameterMissing
      render json: { error: 'Không tìm thấy file attachment để upload.' }, status: :unprocessable_entity
    end

    private

    def default_filename
      "attachment-#{Time.current.strftime('%Y%m%d%H%M%S')}"
    end

    def serialize_attachment(blob)
      {
        id: blob.id,
        url: absolute_assets_url(helpers.rails_storage_proxy_path(blob)),
        filename: blob.filename.to_s,
        byte_size: blob.byte_size,
        created_at: blob.created_at.iso8601
      }
    end
  end
end
