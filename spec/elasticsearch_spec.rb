# Notes:
# The AWS stub_responses() method will set a response for all calls to that
# method. If you call it more than once, then the last call wins. If you call it
# with multiple responses, then it will go through the responses until it gets
# to the last one which will then be returned each subsequent call.
#
# Therefore, we have to ensure each AWS call is made exactly the right number of
# times with the appropriate parameters.
describe ElasticSearch do
  let(:client) { ElasticSearch.class_variable_get('@@client') }
  let(:domain) { 'foo.bar.dev' }

  # This will receive an array of tuples, of the form: [
  #   [ :method1, <params1>, <response1> ]
  #   [ :method2, <params2>, <response2> ]
  #   [ :method1, <params3>, <response3> ]
  # ]
  # TODO: Validate the parameters provided.
  # TODO: Hoist this into a utility and reuse it everywhere.
	def stubber(*expectations)
    requests = {}
    expectations.each do |slice|
      method = slice.first.to_sym
      expectations = slice.last

      requests[method] ||= []
      requests[method].push(expectations)
      requests[method].flatten!
    end

		requests.each do |method, responses|
			client.stub_responses(method, responses)
      expect(client).to receive(method)
        .exactly(responses.size).times
        .and_call_original
		end
	end

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
      before { stubber(retrieve_not_found) }
      it "returns false" do
        expect(ElasticSearch.retrieve(domain)).to be false
      end
    end

    context "when it exists" do
      before { stubber(retrieve_found) }
      it "returns the domain" do
        expect(ElasticSearch.retrieve(domain)).to be_truthy
      end
    end

    context "when it is being deleted" do
      before { stubber(retrieve_found(deleted: true)) }
      it "throws an error" do
        expect{ElasticSearch.retrieve(domain)}.to raise_error "This domain is currently being deleted"
      end
    end
  end

  describe '#create' do
		before { stubber(create_new, retrieve_found) }
		it "returns the domain" do
			expect(ElasticSearch.create(domain)).to be_truthy
		end
  end

  describe '#ensure' do
    context 'when it already exists' do
      before { stubber(retrieve_found) }
			it "returns the domain" do
				expect(ElasticSearch.ensure(domain)).to be_truthy
			end
    end
    context "when it doesn't already exist" do
      before { stubber(retrieve_not_found, create_new, retrieve_found) }
			it "returns the domain" do
				expect(ElasticSearch.ensure(domain)).to be_truthy
			end
    end
  end

  describe '#processing?' do
    context "when it doesn't exist" do
      before { stubber(retrieve_not_found) }
      it "throws an error" do
        expect{ElasticSearch.processing?(domain)}.to raise_error "Elasticsearch domain not found"
      end
    end

    context "when it is processing" do
      before { stubber(retrieve_found(processing: true)) }
      it "returns true" do
        expect(ElasticSearch.processing?(domain)).to be_truthy
      end
    end

    context "when it isn't processing" do
      before { stubber(retrieve_found(processing: false)) }
      it "returns true" do
        expect(ElasticSearch.processing?(domain)).to be_falsy
      end
    end
  end

  describe '#endpoint' do
    context "when it doesn't exist" do
      before { stubber(retrieve_not_found) }
      it "throws an error" do
        expect{ElasticSearch.endpoint(domain)}.to raise_error "Elasticsearch domain not found"
      end
    end

    context "when it has an endpoint" do
      before { stubber(retrieve_found(endpoint: 'foo.bar.com')) }
      it "returns the endpoint" do
        expect(ElasticSearch.endpoint(domain)).to eql 'foo.bar.com'
      end
    end

    context "when it doesn't have an endpoint" do
      before { stubber(retrieve_found) }
      it "returns true" do
        expect(ElasticSearch.endpoint(domain)).to be_falsy
      end
    end
  end

  describe '#endpoint_available?' do
    context "when it doesn't exist" do
      before { stubber(retrieve_not_found) }
      it "throws an error" do
        expect{ElasticSearch.endpoint_available?(domain)}.to raise_error "Elasticsearch domain not found"
      end
    end

    context "when it has an endpoint" do
      before { stubber(retrieve_found(endpoint: 'foo.bar.com')) }
      it "returns true" do
        expect(ElasticSearch.endpoint_available?(domain)).to be true
      end
    end

    context "when it doesn't have an endpoint" do
      before { stubber(retrieve_found) }
      it "returns true" do
        expect(ElasticSearch.endpoint_available?(domain)).to be_falsy
      end
    end
  end

  describe '#ensure_endpoint_available' do
    sleeping_msg = "Elasticsearch domain is still processing...\n"
    context "it exists with an endpoint" do
			before {
        allow(ElasticSearch).to receive(:sleep).with(30).exactly(0).times
      }
      before { stubber(
				retrieve_found(processing: false),
        retrieve_found(endpoint: 'foo.bar.com'),
        retrieve_found(endpoint: 'foo.bar.com'),
			) }
      it "returns the endpoint" do
        expect(ElasticSearch.ensure_endpoint_available(domain)).to eql 'foo.bar.com'
      end
    end

    context "it exists without an endpoint, then with an endpoint" do
      before { stubber(
				retrieve_found(processing: false),
				retrieve_found,
				retrieve_found(processing: false),
        retrieve_found(endpoint: 'foo.bar.com'),
        retrieve_found(endpoint: 'foo.bar.com'),
			) }
      it "returns the endpoint" do
				expect(ElasticSearch).to receive(:sleep).with(30).exactly(1).times
        expect{
          expect(ElasticSearch.ensure_endpoint_available(domain)).to eql 'foo.bar.com'
        }.to output(sleeping_msg).to_stdout
      end
    end

    context "it is still processing, then it exists without an endpoint, then with an endpoint" do
      before { stubber(
				retrieve_found(processing: true),
				retrieve_found(processing: false),
				retrieve_found,
				retrieve_found(processing: false),
        retrieve_found(endpoint: 'foo.bar.com'),
        retrieve_found(endpoint: 'foo.bar.com'),
			) }
      it "returns the endpoint" do
				expect(ElasticSearch).to receive(:sleep).with(30).exactly(2).times
        expect{
          expect(ElasticSearch.ensure_endpoint_available(domain)).to eql 'foo.bar.com'
        }.to output(sleeping_msg + sleeping_msg).to_stdout
      end
    end
  end
end
