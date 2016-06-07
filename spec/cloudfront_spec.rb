describe Cloudfront do
  let(:client) { Cloudfront.class_variable_get('@@client') }

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

  context '#find_distribution_for_domain' do
    context 'when no distributions' do
      before { build_ld_stubs([]) }

      it 'finds nothing' do
        expect(Cloudfront.find_distribution_for_domain('foo.com')).to be nil
      end
    end

    context 'when one distribution' do
      before { build_ld_stubs(['foo.com']) }

      it 'finds the distribution when given the right value' do
        expect(Cloudfront.find_distribution_for_domain('foo.com')).to be_truthy
      end

      it 'finds nothing when given the wrong value' do
        expect(Cloudfront.find_distribution_for_domain('bar.com')).to be nil
      end
    end

    context 'when two distributions' do
      before { build_ld_stubs(['foo.com'], ['bar.com']) }

      it 'finds the distribution' do
        expect(Cloudfront.find_distribution_for_domain('foo.com')).to be_truthy
      end
    end
  end

  context '#ensure_distribution_for_s3' do
  end

  context '#waitfor_distribution_deployed' do
  end
end
