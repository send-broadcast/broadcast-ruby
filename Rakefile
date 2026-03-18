# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'minitest/test_task'

Minitest::TestTask.create do |t|
  t.test_globs = ['test/test_*.rb']
  t.test_prelude = 'ENV["BROADCAST_SKIP_LIVE"] = "1"'
end

Minitest::TestTask.create(:test_live) do |t|
  t.test_globs = ['test/test_live.rb']
end

task default: :test
