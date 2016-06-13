class GhostChef::Route53
  @@client ||= Aws::Route53::Client.new

  def self.zone_for_name(name)
    tld = /([^.]*\.[^.]*)$/.match(name)[1]
    @@client.list_hosted_zones_by_name(
      dns_name: tld,
      max_items: 1,
    ).hosted_zones[0]
  end

  def self.ensure_dns_for_s3(name)
		# S3/us-east-1: Z3AQBSTGFYJSTF
    self.ensure_dns_for(name, 'S3',
			hosted_zone_id: 'Z3AQBSTGFYJSTF',
			dns_name: 's3-website-us-east-1.amazonaws.com',
			evaluate_target_health: true,
    )
  end

  def self.ensure_dns_for_cloudfront(name, distro)
		# CF/us-east-1: Z2FDTNDATAQYW2
    self.ensure_dns_for(name, 'CloudFront',
			hosted_zone_id: 'Z2FDTNDATAQYW2',
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
