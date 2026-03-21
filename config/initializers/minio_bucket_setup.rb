# frozen_string_literal: true

require 'aws-sdk-s3'
require 'socket'

Rails.application.config.after_initialize do
  next unless Rails.env.development?
  next unless ENV.fetch('ACTIVE_STORAGE_SERVICE', nil) == 'minio'

  bucket = ENV.fetch('AWS_BUCKET')
  endpoint = ENV.fetch('AWS_ENDPOINT')

  client = Aws::S3::Client.new(
    access_key_id: ENV.fetch('AWS_ACCESS_KEY_ID'),
    secret_access_key: ENV.fetch('AWS_SECRET_ACCESS_KEY'),
    region: ENV.fetch('AWS_REGION', 'us-east-1'),
    endpoint: endpoint,
    force_path_style: ENV.fetch('AWS_FORCE_PATH_STYLE', 'true') == 'true'
  )

  retries = 5

  begin
    client.head_bucket(bucket: bucket)
  rescue Aws::S3::Errors::NotFound, Aws::S3::Errors::NoSuchBucket
    begin
      client.create_bucket(bucket: bucket)
      Rails.logger.info("Created MinIO bucket #{bucket}")
    rescue Aws::S3::Errors::BucketAlreadyOwnedByYou, Aws::S3::Errors::BucketAlreadyExists
      Rails.logger.info("MinIO bucket #{bucket} already exists")
    end
  rescue Seahorse::Client::NetworkingError => error
    retries -= 1

    if retries.positive?
      sleep 2
      retry
    end

    Rails.logger.warn(
      "Could not reach MinIO at #{endpoint} to ensure bucket #{bucket}: #{error.message}"
    )
  rescue SocketError => error
    Rails.logger.warn(
      "Could not resolve MinIO endpoint #{endpoint} to ensure bucket #{bucket}: #{error.message}"
    )
  end
end
