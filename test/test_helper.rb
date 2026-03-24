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

  def with_stubbed_constructor(klass, fake_instance)
    original_new = klass.method(:new)

    klass.define_singleton_method(:new) do |*args, **kwargs, &block|
      fake_instance
    end

    yield
  ensure
    klass.define_singleton_method(:new) do |*args, **kwargs, &block|
      original_new.call(*args, **kwargs, &block)
    end
  end

  def with_env(overrides)
    previous = {}

    overrides.each do |key, value|
      previous[key] = ENV[key]
      ENV[key] = value
    end

    yield
  ensure
    previous.each do |key, value|
      ENV[key] = value
    end
  end
end
