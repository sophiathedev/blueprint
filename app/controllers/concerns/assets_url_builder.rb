# frozen_string_literal: true

module AssetsUrlBuilder
  extend ActiveSupport::Concern

  private

  def absolute_assets_url(path)
    "#{request.base_url}#{path}"
  end
end
