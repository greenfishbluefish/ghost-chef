describe GhostChef::Cloudfront do
  let(:client) { described_class.class_variable_get('@@client') }

  def ld_response(opts)
    rv = {
      distribution_list: {
        is_truncated: opts[:is_truncated],
        marker: opts[:marker],
        max_items: opts[:total],
        quantity: opts[:items].size,
        items: opts[:items].map do |origin_domain|
          {
            id: 'abcd',
            status: 'available',
            domain_name: origin_domain,
            aliases: { quantity: 0 },
            origins: { quantity: 1, items: [{
              id: 'abcd',
              domain_name: origin_domain,
              origin_path: '/',
            }]},
            last_modified_time: Time.now,
            default_cache_behavior: {
              target_origin_id: 'abcd',
              forwarded_values: {
                query_string: true,
                cookies: { forward: 'all' },
              },
              trusted_signers: {
                enabled: true, quantity: 0,
              },
              viewer_protocol_policy: 'abcd',
              min_ttl: 10,
            },
            cache_behaviors: { quantity: 0 },
            custom_error_responses: { quantity: 0 },
            comment: 'No comment',
            price_class: 'PriceClass_All',
            enabled: true,
            viewer_certificate: {},
            restrictions: { geo_restriction: {
              restriction_type: 'abcd',
              quantity: 0,
            }},
            web_acl_id: 'abcd',
          }
        end,
      }
    }

    if opts[:next_marker]
      rv[:distribution_list][:next_marker] = opts[:next_marker]
    end

    rv
  end

  def build_ld_stubs(*calls)
    total_items = calls.reduce(0) { |sum, items| sum += items.size }
    args = {}
    i = 0

    stubs = []
    running_total = 0
    calls.each do |items|
      running_total += items.size
      marker = "abcd#{i}"
 
      opts = { items: items, marker: marker, total: total_items }
      if running_total < total_items
        opts[:next_marker] = "abcd#{i}"
        opts[:is_truncated] = true
      else
        opts[:is_truncated] = false
      end

      stubs.push([ :list_distributions, args, ld_response(opts) ])

      args = { marker: marker }
      i += 1
    end
    stub_calls(*stubs)
  end

  def cd_response(domain_name)
    {
      distribution: {
        id: 'abcd',
        status: 'pending',
        last_modified_time: Time.now,
        in_progress_invalidation_batches: 0,
        domain_name: domain_name,
        active_trusted_signers: {enabled: false, quantity:0},
        distribution_config: {
          caller_reference: 'abcd',
          origins: {quantity:0},
          default_cache_behavior: {
            target_origin_id: 'abcd',
            forwarded_values: {
              query_string: true,
              cookies: { forward: 'all' },
            },
            trusted_signers: {
              enabled: true,
              quantity: 0,
            },
            viewer_protocol_policy: 'allow-all',
            min_ttl: 10,
          },
          comment: 'abcd',
          enabled: true,
        },
      },
    }
  end

  context '#find_distribution_for_domain' do
    context 'when no distributions' do
      before { build_ld_stubs([]) }

      it 'finds nothing' do
        expect(described_class.find_distribution_for_domain('foo.com')).to be nil
      end
    end

    context 'when one distribution' do
      before { build_ld_stubs(['foo.com']) }

      it 'finds the distribution when given the right value' do
        expect(
          described_class.find_distribution_for_domain('foo.com')
        ).to descend_match(domain_name: 'foo.com')
      end

      it 'finds nothing when given the wrong value' do
        expect(described_class.find_distribution_for_domain('bar.com')).to be nil
      end
    end

    context 'when two distributions' do
      before { build_ld_stubs(['foo.com'], ['bar.com']) }

      it 'finds the distribution' do
        expect(
          described_class.find_distribution_for_domain('foo.com')
        ).to descend_match(domain_name: 'foo.com')
      end
    end
  end

  context '#ensure_distribution_for_s3' do
    context 'when the distribution exists' do
      before { build_ld_stubs(['my-bucket.s3.amazonaws.com']) }

      it 'finds the distribution' do
        expect(
          described_class.ensure_distribution_for_s3('my-bucket')
        ).to descend_match(domain_name: 'my-bucket.s3.amazonaws.com')
      end
    end

    context 'when the distribution does not exist' do
      before { build_ld_stubs([]) }

      it 'creates the distribution with default values' do
        bucket_name = 'my-bucket'

        stub_calls([:create_distribution, {
          distribution_config: {
            caller_reference: bucket_name,
            aliases: {
              quantity: 0,
              items: [],
            },
            default_root_object: 'index.html',
            origins: {
              quantity: 1,
              items: [
                {
                  id: bucket_name,
                  domain_name: "#{bucket_name}.s3.amazonaws.com",
                  s3_origin_config: { origin_access_identity: "" },
                },
              ],
            },
            default_cache_behavior: {
              target_origin_id: bucket_name,
              forwarded_values: {
                query_string: false,
                cookies: { forward: 'all' },
              },
              trusted_signers: {
                enabled: false,
                quantity: 0,
              },
              viewer_protocol_policy: 'allow-all',
              min_ttl: 60,
              max_ttl: 300,
              default_ttl: 60,
            },
            cache_behaviors: { quantity: 0 },
            comment: "Distribution for #{bucket_name}",
            logging: {
              enabled: false,
              include_cookies: false,
              bucket: '',
              prefix: '',
            },
            viewer_certificate: {
              cloud_front_default_certificate: false,
              ssl_support_method: 'sni-only',
              minimum_protocol_version: 'TLSv1',
            },
            enabled: true,
          }
        }, cd_response("#{bucket_name}.s3.amazonaws.com")])

        expect(
          described_class.ensure_distribution_for_s3(bucket_name)
        ).to descend_match(domain_name: "#{bucket_name}.s3.amazonaws.com")
      end

      it 'creates the distribution with SSL override' do
        bucket_name = 'my-bucket'

        stub_calls([:create_distribution, {
          distribution_config: {
            caller_reference: bucket_name,
            aliases: {
              quantity: 0,
              items: [],
            },
            default_root_object: 'index.html',
            origins: {
              quantity: 1,
              items: [
                {
                  id: bucket_name,
                  domain_name: "#{bucket_name}.s3.amazonaws.com",
                  s3_origin_config: { origin_access_identity: "" },
                },
              ],
            },
            default_cache_behavior: {
              target_origin_id: bucket_name,
              forwarded_values: {
                query_string: false,
                cookies: { forward: 'all' },
              },
              trusted_signers: {
                enabled: false,
                quantity: 0,
              },
              viewer_protocol_policy: 'redirect-to-https',
              min_ttl: 60,
              max_ttl: 300,
              default_ttl: 60,
            },
            cache_behaviors: { quantity: 0 },
            comment: "Distribution for #{bucket_name}",
            logging: {
              enabled: false,
              include_cookies: false,
              bucket: '',
              prefix: '',
            },
            viewer_certificate: {
              cloud_front_default_certificate: false,
              ssl_support_method: 'sni-only',
              minimum_protocol_version: 'TLSv1',
              acm_certificate_arn: 'cert1',
              certificate_source: 'acm',
            },
            enabled: true,
          }
        }, cd_response("#{bucket_name}.s3.amazonaws.com")])

        expect(
          described_class.ensure_distribution_for_s3(
            bucket_name, acm_ssl: OpenStruct.new({certificate_arn: 'cert1'}),
          )
        ).to descend_match(domain_name: "#{bucket_name}.s3.amazonaws.com")
      end
    end
  end

  # I don't understand how to stub out a waiter.
  xcontext '#waitfor_distribution_deployed' do
    it "returns true when successful" do
      distro = OpenStruct.new({id: 'abcd'})
      allow_any_instance_of(Kernel).to receive(:sleep)
      stub_calls(
        [:wait_until, [:distribution_deployed, id: distro.id], true],
        #[:get_distribution, {}, nil],
        [:get_distribution, {id: distro.id}, {distribution:{
          id:'abcd',
          status: 'Deployed',
          last_modified_time: Time.now,
          in_progress_invalidation_batches: 0,
          domain_name: 'foo.com',
          active_trusted_signers: {enabled: true, quantity: 0},
          distribution_config: {
            caller_reference: 'abcd',
            origins: {quantity: 0},
            default_cache_behavior: {
              target_origin_id: 'some id',
              forwarded_values: {
                query_string: true, cookies: { forward: 'all' },
              },
              trusted_signers: { enabled: false, quantity: 0 },
              viewer_protocol_policy: 'allow-all',
              min_ttl: 10,
            },
            comment: 'some comment',
            enabled: true,
          },
        }}],
      )
      expect {
        expect(described_class.waitfor_distribution_deployed(distro)).to be true
      }.to output(/Waiting for distribution to be deployed/).to_stdout
    end
  end
end
