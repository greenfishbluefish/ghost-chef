Gem::Specification.new do |s|
  s.name        = 'aws-idempotency'
  s.version     = '0.0.1'
  s.date        = '2016-02-08'
  s.summary     = "Deploy to AWS with idempotency"
  s.description = "Deploy to AWS with idempotency"
  s.authors     = ["Rob Kinyon"]
  s.email       = ''
  s.files       = Dir.glob("{bin,lib}/**/*") + %w(README.md)
  s.homepage    = ''
  s.license     = 'MIT'

  s.add_runtime_dependency 'aws-sdk', '~> 2.1'
end
