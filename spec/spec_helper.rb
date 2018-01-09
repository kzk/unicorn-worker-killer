require 'bundler/setup'
require 'rspec'
require 'timecop'

require 'unicorn/worker_killer'
require 'support/fake_http_server'

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
