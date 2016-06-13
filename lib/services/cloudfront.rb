class GhostChef::Cloudfront
  @@client ||= Aws::CloudFront::Client.new

  def self.filter(methods, args, key, &filter)
    GhostChef::Util.filter(@@client, methods, args, key, [:next_marker, :marker], &filter)
  end

  def self.find_distribution_for_domain(domain)
    filter([:list_distributions, :distribution_list], {}, :items) do |item|
      domain_not_found = item.origins.items.select do |origin|
        origin.domain_name == domain
      end.empty?
      domain_not_found ? false : item
    end.first
  end

  def self.ensure_distribution_for_s3(bucket, opts={})
    distro = find_distribution_for_domain("#{bucket}.s3.amazonaws.com")
    unless distro
      opts[:aliases] ||= []

      ssl_options = {
        cloud_front_default_certificate: false,
      }
      protocol_policy = 'allow-all'
      if opts[:acm_ssl]
        ssl_options = {
          cloud_front_default_certificate: false,
          acm_certificate_arn: opts[:acm_ssl].certificate_arn,
          certificate_source: 'acm',
        }
        protocol_policy = 'redirect-to-https'
      end
      ssl_options[:ssl_support_method] = 'sni-only'
      ssl_options[:minimum_protocol_version] = 'TLSv1'

      distro = @@client.create_distribution(
        distribution_config: {
          caller_reference: bucket,
          aliases: {
            quantity: opts[:aliases].length,
            items: opts[:aliases],
          },
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
            viewer_protocol_policy: protocol_policy,
            min_ttl: 60,
            max_ttl: 300,
            default_ttl: 60,
          },
          cache_behaviors: { quantity: 0 },
          comment: "Distribution for #{bucket}",
          logging: {
            enabled: false,
            include_cookies: false,
            bucket: '',
            prefix: '',
          },
          viewer_certificate: ssl_options,
          enabled: true,
        }
      ).distribution
    end
    distro
  end

  def self.waitfor_distribution_deployed(distro)
    puts "Waiting for distribution to be deployed ..."
    puts "\t(This can take up to 20 minutes.)"

    @@client.wait_until(:distribution_deployed, id: distro.id)
  end
end
