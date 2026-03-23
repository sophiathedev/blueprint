# frozen_string_literal: true

ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
abort('The Rails environment is running in production mode!') if Rails.env.production?
require 'rails/test_help'
require 'sidekiq/testing'

Sidekiq::Testing.fake!

class ActiveSupport::TestCase
  parallelize(workers: :number_of_processors)

  setup do
    Sidekiq::Worker.clear_all
  end
end
