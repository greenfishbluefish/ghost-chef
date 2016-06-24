require File.expand_path('../lib/ghost-chef/version', __FILE__)

Gem::Specification.new do |gem|
  gem.name = 'ghost-chef'
  gem.version = GhostChef::VERSION
  gem.date = Date.today.to_s

  gem.licenses = ['MIT']

  gem.files = Dir['Rakefile', 'README*', '{bin,lib,spec}/**/*']

  gem.add_dependency('aws-sdk', [">=2.0.0"])
  gem.add_development_dependency('rspec')
  gem.add_development_dependency('simplecov')

  gem.summary = "An idempotent way to use AWS"
  gem.description = "The AWS SDK is an amazing way to interact with AWS and the resources it provides. However, the SDK itself is imperative, not idempotent, making it harder to use that it should be. GhostChef bridges that imperative/idempotent gap along with providing useful sugaring and defaults to many standard tasks."

  gem.authors = [ 'Rob Kinyon' ]
  gem.email = 'rob.kinyon@gmail.com'
  gem.homepage = 'https://github.com/greenfishbluefish/aws-idempotency'
end
