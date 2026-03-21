# frozen_string_literal: true

# Fix for NameError: uninitialized constant Pry::Pager::SimplePager::Readline
# when running in Docker environments with many results.
Pry.config.pager = false if defined?(Pry)
