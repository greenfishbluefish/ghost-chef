describe Route53 do
  let(:client) { Route53.class_variable_get('@@client') }

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

  context '#zone_for_name' do
    context 'with no zones found' do
      before {stub_calls(
        [hz_call, hz_request('foo.com'), hz_response([])],
      )}
      it "returns nil" do
        expect(Route53.zone_for_name('foo.com')).to be nil
      end
    end

    context 'with one zone found' do
      before {stub_calls(
        [hz_call, hz_request('foo.com'), hz_response(['foo.com'])],
      )}

      it "returns the TLD for the TLD" do
        expect(Route53.zone_for_name('foo.com').name).to eql 'foo.com'
      end

      it "returns the TLD for a subdomain" do
        expect(Route53.zone_for_name('www.foo.com').name).to eql 'foo.com'
      end
    end
  end

  hosted_zone_targets = {
    S3: 'Z3AQBSTGFYJSTF',
    CloudFront: 'Z2FDTNDATAQYW2',
  }

  context '#ensure_dns_for_s3' do
    context 'with no zones found' do
      before {stub_calls(
        [hz_call, hz_request('foo.com'), hz_response([])],
      )}
      it "returns false" do
        expect(Route53.ensure_dns_for_s3('foo.com')).to be_falsy
      end
    end

    context 'with the zone found' do
      before {stub_calls(
        [hz_call, hz_request('foo.com'), hz_response(['foo.com'])],
      )}

      it 'returns a record already there for a root' do
        name = 'foo.com'
        expect(client).to receive(:list_resource_record_sets)
          .with(
            hosted_zone_id: 'abcd',
            start_record_name: name,
            max_items: 1,
          ).and_call_original

        client.stub_responses(:list_resource_record_sets, {
          is_truncated: false, max_items: 1,
          resource_record_sets: [
            { name: "#{name}.", type: 'A' },
          ],
        })

        expect(Route53.ensure_dns_for_s3(name)).to be true
      end

      it 'returns a record already there for a subdomain' do
        name = 'www.foo.com'
        expect(client).to receive(:list_resource_record_sets)
          .with(
            hosted_zone_id: 'abcd',
            start_record_name: name,
            max_items: 1,
          ).and_call_original

        client.stub_responses(:list_resource_record_sets, {
          is_truncated: false, max_items: 1,
          resource_record_sets: [
            { name: "#{name}.", type: 'A' },
          ],
        })

        expect(Route53.ensure_dns_for_s3(name)).to be true
      end

      it 'creates a record if needed' do
        name = 'www.foo.com'

        expect(client).to receive(:list_resource_record_sets)
          .with(
            hosted_zone_id: 'abcd',
            start_record_name: name,
            max_items: 1,
          ).and_call_original

        client.stub_responses(:list_resource_record_sets, {
          is_truncated: false, max_items: 1,
          resource_record_sets: [],
        })

        expect(client).to receive(:change_resource_record_sets)
          .with(
            hosted_zone_id: 'abcd',
            change_batch: {
              comment: "Create DNS for S3 #{name}",
              changes: [
                {
                  action: "CREATE",
                  resource_record_set: {
                    name: "#{name}.",
                    type: 'A',
                    alias_target: {
                      hosted_zone_id: hosted_zone_targets[:S3],
                      dns_name: 's3-website-us-east-1.amazonaws.com',
                      evaluate_target_health: true,
                    },
                  },
                },
              ],
            },
          ).and_call_original

        client.stub_responses(:change_resource_record_sets, { change_info: {
          id: 'abcd', status: 'PENDING', comment: "Create DNS for S3 #{name}",
          submitted_at: Time.now,
        }})
        expect(Route53.ensure_dns_for_s3(name)).to be true
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
        expect(Route53.ensure_dns_for_cloudfront('foo.com', cloudfront)).to be false
      end
    end

    context 'with the zone found' do
      before {stub_calls(
        [hz_call, hz_request('foo.com'), hz_response(['foo.com'])],
      )}

      it 'returns a record already there for a root' do
        name = 'foo.com'
        expect(client).to receive(:list_resource_record_sets)
          .with(
            hosted_zone_id: 'abcd',
            start_record_name: name,
            max_items: 1,
          ).and_call_original

        client.stub_responses(:list_resource_record_sets, {
          is_truncated: false, max_items: 1,
          resource_record_sets: [
            { name: "#{name}.", type: 'A' },
          ],
        })

        expect(Route53.ensure_dns_for_cloudfront(name, cloudfront)).to be true
      end

      it 'returns a record already there for a subdomain' do
        name = 'www.foo.com'
        expect(client).to receive(:list_resource_record_sets)
          .with(
            hosted_zone_id: 'abcd',
            start_record_name: name,
            max_items: 1,
          ).and_call_original

        client.stub_responses(:list_resource_record_sets, {
          is_truncated: false, max_items: 1,
          resource_record_sets: [
            { name: "#{name}.", type: 'A' },
          ],
        })

        expect(Route53.ensure_dns_for_cloudfront(name, cloudfront)).to be true
      end

      it 'creates a record if needed' do
        name = 'www.foo.com'

        expect(client).to receive(:list_resource_record_sets)
          .with(
            hosted_zone_id: 'abcd',
            start_record_name: name,
            max_items: 1,
          ).and_call_original

        client.stub_responses(:list_resource_record_sets, {
          is_truncated: false, max_items: 1,
          resource_record_sets: [],
        })

        expect(client).to receive(:change_resource_record_sets)
          .with(
            hosted_zone_id: 'abcd',
            change_batch: {
              comment: "Create DNS for CloudFront #{name}",
              changes: [
                {
                  action: "CREATE",
                  resource_record_set: {
                    name: "#{name}.",
                    type: 'A',
                    alias_target: {
                      hosted_zone_id: hosted_zone_targets[:CloudFront],
                      dns_name: cf_domain,
                      evaluate_target_health: false,
                    },
                  },
                },
              ],
            },
          ).and_call_original

        client.stub_responses(:change_resource_record_sets, { change_info: {
          id: 'abcd', status: 'PENDING', comment: "Create DNS for CloudFront #{name}",
          submitted_at: Time.now,
        }})
        expect(Route53.ensure_dns_for_cloudfront(name, cloudfront)).to be true
      end
    end
  end
end
