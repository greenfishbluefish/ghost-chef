describe GhostChef::Route53 do
  let(:client) { GhostChef::Route53.class_variable_get('@@client') }

  let(:hz_call) { :list_hosted_zones_by_name }
  def hz_request(name)
    {
      dns_name: 'foo.com',
      max_items: 1,
    }
  end
  def hz_response(names)
    {
      hosted_zones: names.map {|n|
        { name: n, id: 'abcd', caller_reference: 'abcd' }
      },
      is_truncated: false,
      max_items: names.size.to_i,
    }
  end

  let(:lrr_call) { :list_resource_record_sets }
  def lrr_request(name)
    {
      hosted_zone_id: 'abcd',
      start_record_name: name,
      max_items: 1,
    }
  end
  def lrr_response(names)
    {
      is_truncated: false,
      max_items: names.size,
      resource_record_sets: names.map do |name|
        { name: "#{name}.", type: 'A' }
      end,
    }
  end

  let(:hosted_zone_targets) {{
    S3: 'Z3AQBSTGFYJSTF',
    CloudFront: 'Z2FDTNDATAQYW2',
  }}

  let(:crr_call) { :change_resource_record_sets }
  def crr_request(type, name, opts)
    {
      hosted_zone_id: 'abcd',
      change_batch: {
        comment: "Create DNS for #{type} #{name}",
        changes: [
          {
            action: "CREATE",
            resource_record_set: {
              name: "#{name}.",
              type: 'A',
              alias_target: opts[:target].merge(
                hosted_zone_id: hosted_zone_targets[type],
              ),
            },
          },
        ],
      },
    }
  end
  def crr_response(type, name)
    {
      change_info: {
        id: 'abcd',
        status: 'PENDING',
        comment: "Create DNS for #{type} #{name}",
        submitted_at: Time.now,
      },
    }
  end

  context '#zone_for_name' do
    context 'with no zones found' do
      before {stub_calls(
        [hz_call, hz_request('foo.com'), hz_response([])],
      )}
      it "returns nil" do
        expect(GhostChef::Route53.zone_for_name('foo.com')).to be nil
      end
    end

    context 'with one zone found' do
      before {stub_calls(
        [hz_call, hz_request('foo.com'), hz_response(['foo.com'])],
      )}

      it "returns the TLD for the TLD" do
        expect(GhostChef::Route53.zone_for_name('foo.com').name).to eql 'foo.com'
      end

      it "returns the TLD for a subdomain" do
        expect(GhostChef::Route53.zone_for_name('www.foo.com').name).to eql 'foo.com'
      end
    end
  end

  context '#ensure_dns_for_s3' do
    context 'with no zones found' do
      before {stub_calls(
        [hz_call, hz_request('foo.com'), hz_response([])],
      )}
      it "returns false" do
        expect(GhostChef::Route53.ensure_dns_for_s3('foo.com')).to be_falsy
      end
    end

    context 'with the zone found' do
      before {stub_calls(
        [hz_call, hz_request('foo.com'), hz_response(['foo.com'])],
      )}

      it 'returns a record already there for a root' do
        name = 'foo.com'
        stub_calls(
          [lrr_call, lrr_request(name), lrr_response([name])],
        )
        expect(GhostChef::Route53.ensure_dns_for_s3(name)).to be true
      end

      it 'returns a record already there for a subdomain' do
        name = 'www.foo.com'
        stub_calls(
          [lrr_call, lrr_request(name), lrr_response([name])],
        )

        expect(GhostChef::Route53.ensure_dns_for_s3(name)).to be true
      end

      it 'creates a record if needed' do
        name = 'www.foo.com'
        stub_calls(
          [lrr_call, lrr_request(name), lrr_response([])],
          [
            crr_call,
            crr_request(
              :S3, name, target: {
                dns_name: 's3-website-us-east-1.amazonaws.com',
                evaluate_target_health: true,
              },
            ),
            crr_response(:CloudFront, name),
          ],
        )

        expect(GhostChef::Route53.ensure_dns_for_s3(name)).to be true
      end
    end
  end

  context '#ensure_dns_for_cloudfront' do
    let(:cf_domain) { 'cloudfront.aws.com' }
    let(:cloudfront) { OpenStruct.new({domain_name: cf_domain}) }

    context 'with no zones found' do
      before {stub_calls(
        [hz_call, hz_request('foo.com'), hz_response([])],
      )}
      it "returns false" do
        expect(GhostChef::Route53.ensure_dns_for_cloudfront('foo.com', cloudfront)).to be false
      end
    end

    context 'with the zone found' do
      before {stub_calls(
        [hz_call, hz_request('foo.com'), hz_response(['foo.com'])],
      )}

      it 'returns a record already there for a root' do
        name = 'foo.com'
        stub_calls(
          [lrr_call, lrr_request(name), lrr_response([name])],
        )

        expect(GhostChef::Route53.ensure_dns_for_cloudfront(name, cloudfront)).to be true
      end

      it 'returns a record already there for a subdomain' do
        name = 'www.foo.com'
        stub_calls(
          [lrr_call, lrr_request(name), lrr_response([name])],
        )

        expect(GhostChef::Route53.ensure_dns_for_cloudfront(name, cloudfront)).to be true
      end

      it 'creates a record if needed' do
        name = 'www.foo.com'
        stub_calls(
          [lrr_call, lrr_request(name), lrr_response([])],
          [
            crr_call,
            crr_request(
              :CloudFront, name, target: {
                dns_name: cf_domain,
                evaluate_target_health: false,
              },
            ),
            crr_response(:CloudFront, name),
          ],
        )

        expect(GhostChef::Route53.ensure_dns_for_cloudfront(name, cloudfront)).to be true
      end
    end
  end
end
