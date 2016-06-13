require 'aws-sdk'

Aws.config.update({
  region: 'us-east-1',
})

module GhostChef
	VERSION = '0.0.1'
  class Error < RuntimeError; end
end

require_relative 'util'

require_relative 'services/junk_drawer'
require_relative 'services/elastic_search'
require_relative 'services/s3'
require_relative 'services/dns'
require_relative 'services/cloudfront'
require_relative 'services/certificates'
require_relative 'services/notification'
