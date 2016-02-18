Gem::Specification.new do |s|
  s.name        = 'aws-idempotency'
  s.version     = '0.0.2'
  s.date        = '2016-02-18'
  s.summary     = "Deploy to AWS with idempotency"
  s.description = "Deploy to AWS with idempotency"
  s.authors     = ["Cyanna"]
  s.email       = 'it@cyanna.com'
  s.files       = Dir.glob("{bin,lib}/**/*") + %w(README.md)
  s.homepage    = ''
  s.license     = ''

  s.add_runtime_dependency 'aws-sdk', '~> 2.1'
end
