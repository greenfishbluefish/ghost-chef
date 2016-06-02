describe Route53 do
  let(:client) { Route53.class_variable_get('@@client') }
  def build_list_hosted_zones_by_name(zones)
    client.stub_responses(:list_hosted_zones_by_name, {
      hosted_zones: zones,
      is_truncated: false,
      max_items: zones.size.to_i,
    })
  end

  context '#zone_for_name' do
    context 'with no zones found' do
      before(:each) { build_list_hosted_zones_by_name([]) }
      it "returns nil" do
				expect(client).to receive(:list_hosted_zones_by_name)
					.with(
						dns_name: 'foo.com',
            max_items: 1,
					).and_call_original
        expect(Route53.zone_for_name('foo.com')).to be nil
      end
    end

    context 'with one zone found' do
      before(:each) { build_list_hosted_zones_by_name([{
         id: 'abcd', caller_reference: 'abcd',
         name:'foo.com'
      }]) }

      it "returns the TLD for the TLD" do
				expect(client).to receive(:list_hosted_zones_by_name)
					.with(
						dns_name: 'foo.com',
            max_items: 1,
					).and_call_original
        expect(Route53.zone_for_name('foo.com').name).to eql 'foo.com'
      end

      it "returns the TLD for a subdomain" do
				expect(client).to receive(:list_hosted_zones_by_name)
					.with(
						dns_name: 'foo.com',
            max_items: 1,
					).and_call_original
        expect(Route53.zone_for_name('www.foo.com').name).to eql 'foo.com'
      end
    end
  end
end
