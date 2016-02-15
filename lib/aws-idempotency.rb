require 'aws-sdk'

Aws.config.update({
  region: 'us-east-1',
})

require_relative 'services/junk_drawer.rb'
require_relative 'services/elastic_search.rb'

