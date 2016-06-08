require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
  minimum_coverage 41
  minimum_coverage_by_file 19
  refuse_coverage_drop
end

# Because the clients are created eagerly (upon class load), we have to set the
# AWS SDK to stubbed before we load aws-idempotency.
require 'aws-sdk'
Aws.config.update({
  stub_responses: true,
})

require 'aws-idempotency'

require 'aws_stubbing'

RSpec.configure do |config|
  config.include AwsStubs

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  # rspec-mocks config goes here. You can use an alternate test double
  # library (such as bogus or mocha) by changing the `mock_with` option here.
  config.mock_with :rspec do |mocks|
    # Prevents you from mocking or stubbing a method that does not exist on
    # a real object. This is generally recommended, and will default to
    # `true` in RSpec 4.
    mocks.verify_partial_doubles = true
  end

  #config.disable_monkey_patching!

  config.warnings = true

  if config.files_to_run.one?
    config.default_formatter = 'doc'
  end

  config.profile_examples = 2

  config.order = :random
  Kernel.srand config.seed
end
