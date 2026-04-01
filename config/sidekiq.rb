# frozen_string_literal: true

sidekiq_concurrency = Integer(ENV.fetch('SIDEKIQ_CONCURRENCY', 5), exception: false)
sidekiq_concurrency = 5 if sidekiq_concurrency.nil? || sidekiq_concurrency < 1

sidekiq_config = { url: ENV['REDIS_URL'] }

Sidekiq.configure_server do |config|
  config.redis = sidekiq_config
  config[:concurrency] = sidekiq_concurrency
end

Sidekiq.configure_client do |config|
  config.redis = sidekiq_config
end
