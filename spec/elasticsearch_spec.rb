describe GhostChef::ElasticSearch do
  let(:client) { described_class.class_variable_get('@@client') }
  let(:domain) { 'foo.bar.dev' }

  def build_request
    { domain_name: domain }
  end
  def build_response(opts={})
    {
      domain_status: {
        domain_id: 'abcd',
        domain_name: domain,
        arn: 'efgh',
        elasticsearch_cluster_config: {
          instance_type: 'm3.medium.elasticsearch',
          instance_count: 1,
        },
      }.merge(opts),
    }
  end

  def retrieve_not_found
    [:describe_elasticsearch_domain, build_request, 'ResourceNotFoundException']
  end
  def retrieve_found(opts={})
    [:describe_elasticsearch_domain, build_request, build_response(opts)]
  end
  def create_new(opts={})
    [:create_elasticsearch_domain, build_request, build_response(opts)]
  end

  describe '#retrieve' do
    context "when it doesn't exist" do
      before { stub_calls(retrieve_not_found) }
      it "returns false" do
        expect(described_class.retrieve(domain)).to be nil
      end
    end

    context "when it exists" do
      before { stub_calls(retrieve_found) }
      it "returns the domain" do
        expect(described_class.retrieve(domain)).to be_truthy
      end
    end

    context "when it is being deleted" do
      before { stub_calls(retrieve_found(deleted: true)) }
      it "throws an error" do
        expect{described_class.retrieve(domain)}.to raise_error GhostChef::Error, "This domain is currently being deleted"
      end
    end
  end

  describe '#ensure' do
    context 'when it already exists' do
      before { stub_calls(retrieve_found) }
      it "returns the domain" do
        expect(described_class.ensure(domain)).to be_truthy
      end
    end
    context "when it doesn't already exist" do
      before { stub_calls(retrieve_not_found, create_new, retrieve_found) }
      it "returns the domain" do
        expect(described_class.ensure(domain)).to be_truthy
      end
    end
  end

  describe '#ensure_endpoint_available' do
    context "when it doesn't exist" do
      before { stub_calls(retrieve_not_found) }
      it "throws an error" do
        expect{described_class.ensure_endpoint_available(domain)}.to raise_error GhostChef::Error, "Domain does not exist"
      end
    end

    sleeping_msg = "Elasticsearch domain is still processing...\n"
    context "it exists with an endpoint" do
      before {
        allow(described_class).to receive(:sleep).with(30).exactly(0).times
      }
      before { stub_calls(
        retrieve_found(processing: false, endpoint: 'foo.bar.com'),
      ) }
      it "returns the endpoint" do
        expect(described_class.ensure_endpoint_available(domain)).to eql 'foo.bar.com'
      end
    end

    context "it exists without an endpoint, then with an endpoint" do
      before { stub_calls(
        retrieve_found(processing: false, endpoint: nil),
        # Sleep here
        retrieve_found(processing: false, endpoint: 'foo.bar.com'),
      ) }
      it "returns the endpoint" do
        expect(described_class).to receive(:sleep).with(30).exactly(1).times
        expect{
          expect(described_class.ensure_endpoint_available(domain)).to eql 'foo.bar.com'
        }.to output(sleeping_msg).to_stdout
      end
    end

    context "it is still processing, then it exists without an endpoint, then with an endpoint" do
      before { stub_calls(
        retrieve_found(processing: true),
        # Sleep here
        retrieve_found(processing: false, endpoint: nil),
        # Sleep here
        retrieve_found(processing: false, endpoint: 'foo.bar.com'),
      ) }
      it "returns the endpoint" do
        expect(described_class).to receive(:sleep).with(30).exactly(2).times
        expect{
          expect(described_class.ensure_endpoint_available(domain)).to eql 'foo.bar.com'
        }.to output(sleeping_msg + sleeping_msg).to_stdout
      end
    end
  end
end
