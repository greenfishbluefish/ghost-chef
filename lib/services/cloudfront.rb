class Cloudfront
  @@client ||= Aws::CloudFront::Client.new

  def self.filter(method, args, key, &filter)
    resp = @@client.send(method.to_sym, **args).distribution_list
    items = resp.send(key.to_sym).select(&filter)
    while resp.next_marker
      resp = @@client.send(
        method.to_sym, **args.merge(marker: resp.next_marker)
      ).distribution_list
      items.concat!(resp.send(key.to_sym).select(&filter))
    end
    items
  end

  def self.find_distribution_for_domain(domain)
    filter(:list_distributions, {}, :items) do |item|
      domain_not_found = item.origins.items.select do |origin|
        origin.domain_name == domain
      end.empty?
      domain_not_found ? false : item
    end.first
  end

  def self.ensure_distribution_for_s3(bucket, opts={})
    distro = find_distribution_for_domain(bucket)
    unless distro
      distro = @@client.create_distribution(
        distribution_config: {
          caller_reference: bucket,
          default_root_object: 'index.html',
          origins: {
            quantity: 1,
            items: [
              {
                id: bucket,
                domain_name: "#{bucket}.s3.amazonaws.com",
                s3_origin_config: { origin_access_identity: "" },
              },
            ],
          },
          default_cache_behavior: {
            target_origin_id: bucket,
            forwarded_values: {
              query_string: false,
              cookies: { forward: 'all' },
            },
            trusted_signers: {
              enabled: false,
              quantity: 0,
            },
            viewer_protocol_policy: 'allow-all',
            min_ttl: 300,
          },
          cache_behaviors: { quantity: 0 },
          comment: bucket,
          logging: {
            enabled: false,
            include_cookies: false,
            bucket: '',
            prefix: '',
          },
          enabled: true,
        }
      ).distribution

      puts "Waiting for distribution to be deployed ..."
      @@client.wait_until(:distribution_deployed, id: distro.id)
    end
    distro
  end
end
