##
# = GhostChef
# Your idempotent manager of AWS resources.
# = Purpose
# The AWS SDK is ridiculously good. You have programmatic access to literally
# every single thing you can do through the UI (because the UI, itself, uses the
# SDK for every action - you should take notes). The only problem is that the
# SDK's interface is imperative, not idempotent. GhostChef attempts to bridge
# that gap by providing methods which don't _do_, they _ensure_. In the process,
# GhostChef also attempts to provide useful methods for common tasks, such as
# creating a static website in S3 that's accessible through HTTPS.
# = Configuration
# == Credentials
# Any usage of AWS should start with how credentials are managed. GhostChef does
# *NOT* manage credentials in any way - it defers that to the Aws::SDK. Please
# q.v. http://docs.aws.amazon.com/sdkforruby/api/#Configuration for details.
# == Region
# In 0.0.1, the region is hard-coded to us-east-1. This *WILL* change very
# quickly.
# == Client
# GhostChef is designed so that you shouldn't need to access the AWS client
# directly. If you feel a need to do so, you can ask each class for its client.
# = Usage
# All methods are class methods. This is very similar to how you would interact
# with an idempotency tool, like Chef or Puppet. Where an object must be
# provided (e.g., GhostChef::Notifications.ensure_subscription() which takes a
# topic), you should use the ensure method for that object (e.g.,
# GhostChef::Notifications.ensure_topic()) to retrieve the topic object.
#
# See the documentation for each method for further explanation and examples.
require_relative 'ghost-chef/version'

require 'aws-sdk'

Aws.config.update({
  region: 'us-east-1',
})

require_relative 'ghost-chef/util'

require_relative 'services/certificates'
require_relative 'services/cloudfront'
require_relative 'services/dns'
require_relative 'services/elastic_search'
require_relative 'services/iam'
require_relative 'services/load_balancer'
require_relative 'services/notification'
require_relative 'services/s3'

require_relative 'services/junk_drawer'
