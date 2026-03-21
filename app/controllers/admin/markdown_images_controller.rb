# frozen_string_literal: true

module Admin
  class MarkdownImagesController < BaseController
    DEFAULT_IMAGE_LIMIT = 10
    MAX_IMAGE_LIMIT = 10
    MAX_FILE_SIZE = 64.megabytes

    def index
      limit = [params.fetch(:limit, DEFAULT_IMAGE_LIMIT).to_i, MAX_IMAGE_LIMIT].min
      offset = [params.fetch(:offset, 0).to_i, 0].max

      images = ActiveStorage::Blob
        .where('content_type LIKE ?', 'image/%')
        .order(created_at: :desc)
        .limit(limit)
        .offset(offset)

      render json: {
        images: images.map { |image| serialize_image(image) },
        next_offset: offset + images.length,
        has_more: images.length == limit
      }
    end

    def create
      uploaded_file = params.require(:image)

      unless uploaded_file.content_type.to_s.start_with?('image/')
        return render json: { error: 'Chỉ hỗ trợ upload hình ảnh.' }, status: :unprocessable_entity
      end

      if uploaded_file.size.to_i > MAX_FILE_SIZE
        return render json: { error: 'Ảnh vượt quá giới hạn 64MB.' }, status: :unprocessable_entity
      end

      blob = ActiveStorage::Blob.create_and_upload!(
        io: uploaded_file.tempfile.tap(&:rewind),
        filename: uploaded_file.original_filename.presence || default_filename_for(uploaded_file.content_type),
        content_type: uploaded_file.content_type
      )

      render json: serialize_image(blob), status: :created
    rescue ActionController::ParameterMissing
      render json: { error: 'Không tìm thấy file ảnh để upload.' }, status: :unprocessable_entity
    end

    private

    def default_filename_for(content_type)
      extension = Rack::Mime::MIME_TYPES.invert[content_type].presence || '.png'
      "pasted-image-#{Time.current.strftime('%Y%m%d%H%M%S')}#{extension}"
    end

    def serialize_image(blob)
      {
        id: blob.id,
        url: helpers.rails_storage_proxy_url(blob, host: request.base_url),
        filename: blob.filename.to_s,
        byte_size: blob.byte_size,
        created_at: blob.created_at.iso8601
      }
    end
  end
end
