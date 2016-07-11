##
# This class manages all interaction with Route53, Amazon's DNS service.
class GhostChef::Route53
  @@client ||= Aws::Route53::Client.new

  ##
  # This method returns the AWS Route53 Zone for a given domain name, if one
  # exists.
  def self.zone_for_name(name)
    tld = /([^.]*\.[^.]*)$/.match(name)[1]
    @@client.list_hosted_zones_by_name(
      dns_name: tld,
      max_items: 1,
    ).hosted_zones.first
  end

  #--
  # These are taken from AWS documentation.
  # TODO: Figure out how to look these up on-demand.
  #++
  @@hosted_zone_ids = {
    S3: {
      'us-east-1' => 'Z3AQBSTGFYJSTF',
    },
    CloudFront: {
      'us-east-1' => 'Z2FDTNDATAQYW2',
    },
  }

  ##
  # This method will ensure that a DNS record exists for a S3 bucket. The S3
  # bucket needs to be named with the DNS name you wish to use. For example, if
  # you want to serve the static website 'www.foo.com', then you will need to
  # name the S3 bucket 'www.foo.com'.
  def self.ensure_dns_for_s3(name)
    self.ensure_dns_for(name, 'S3',
			hosted_zone_id: @@hosted_zone_ids[:S3]['us-east-1'],
			dns_name: 's3-website-us-east-1.amazonaws.com',
			evaluate_target_health: true,
    )
  end

  ##
  # This method will ensure that a DNS record exists for a CloudFront
  # distribution. The CloudFront domain will need to be aware that it is serving
  # content for this domain name.
  def self.ensure_dns_for_cloudfront(name, distro)
    self.ensure_dns_for(name, 'CloudFront',
			hosted_zone_id: @@hosted_zone_ids[:CloudFront]['us-east-1'],
			dns_name: distro.domain_name,
			evaluate_target_health: false,
    )
  end

  private

  def self.ensure_dns_for(name, type, **alias_target)
    zone = zone_for_name(name) or return false

    record = @@client.list_resource_record_sets(
      hosted_zone_id: zone.id,
      start_record_name: name,
      max_items: 1,
    ).resource_record_sets[0]

    # TODO: Determine if the record found is the alias we want.

    if !record or record.name != "#{name}."
      record = @@client.change_resource_record_sets(
        hosted_zone_id: zone.id,
        change_batch: {
          comment: "Create DNS for #{type} #{name}",
          changes: [
            {
              action: "CREATE",
              resource_record_set: {
                name: "#{name}.",
                type: 'A',
                alias_target: alias_target,
              },
            },
          ],
        },
      )
    end

    true
	end
end
