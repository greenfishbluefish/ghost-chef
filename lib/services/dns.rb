class Route53
  @@client ||= Aws::Route53::Client.new

  def self.zone_for_name(name)
    tld = /([^.]*\.[^.]*)$/.match(name)[1]
    @@client.list_hosted_zones_by_name(
      dns_name: tld,
      max_items: 1,
    ).hosted_zones[0]
  end

  def self.ensure_dns_for_s3(name)
    zone = zone_for_name(name) or return false

    record = @@client.list_resource_record_sets(
      hosted_zone_id: zone.id,
      start_record_name: name,
      max_items: 1,
    ).resource_record_sets[0]

    # TODO: Determine if the record found is the alias we want.

    if !record or record.name != "#{name}."
      # Cloudfront: Z2FDTNDATAQYW2
      # S3/us-east-1: Z3AQBSTGFYJSTF
      record = @@client.change_resource_record_sets(
        hosted_zone_id: zone.id,
        change_batch: {
          comment: "Create DNS for S3 #{name}",
          changes: [
            {
              action: "CREATE",
              resource_record_set: {
                name: "#{name}.",
                type: 'A',
                alias_target: {
                  hosted_zone_id: 'Z3AQBSTGFYJSTF',
                  dns_name: 's3-website-us-east-1.amazonaws.com',
                  evaluate_target_health: true,
                },
              },
            },
          ],
        },
      )
    end
    record
  end
end
