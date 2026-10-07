# frozen_string_literal: true

require "minitest/test_task"

Minitest::TestTask.create

desc "Lint with RuboCop"
task :rubocop do
  sh "bundle exec rubocop"
end

task default: %i[test rubocop]
