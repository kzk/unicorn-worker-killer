require 'bundler/setup'
require 'rspec'

require 'unicorn/worker_killer'

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
