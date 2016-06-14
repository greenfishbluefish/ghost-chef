describe GhostChef::Notifications do
  let(:client) { described_class.class_variable_get('@@client') }

  describe '#retrieve_topic' do
    context "when it doesn't exist" do
      before { stub_calls([:list_topics, {}, {topics:[]}]) }
      it "returns nil" do
        expect(described_class.retrieve_topic('foo')).to be nil
      end
    end

    context "when it exists alone" do
      before { stub_calls([:list_topics, {}, {topics:[{topic_arn:'abcd:foo'}]}]) }
      it "returns the topic" do
        expect(
          described_class.retrieve_topic('foo')
        ).to descend_match topic_arn: 'abcd:foo'
      end
    end

    context "when multiples exist" do
      before { stub_calls(
        [:list_topics, {}, {topics:[
          {topic_arn: 'abcd:foo'},
          {topic_arn: 'efgh:bar'},
        ]}]
      ) }

      it "returns the topic" do
        expect(
          described_class.retrieve_topic('foo')
        ).to descend_match topic_arn: 'abcd:foo'
      end

      it "returns nil when not found" do
        expect(described_class.retrieve_topic('baz')).to be nil
      end
    end
  end

  describe '#ensure_topic' do
    context "when it already exists" do
      before { stub_calls([:list_topics, {}, {topics:[{topic_arn:'abcd:foo'}]}]) }
      it "returns the topic" do
        expect(
          described_class.ensure_topic('foo')
        ).to descend_match topic_arn: 'abcd:foo'
      end
    end

    context "when it doesn't exist" do
      before { stub_calls(
        [:list_topics, {}, {topics:[]}],
        [:create_topic, {name: 'foo'}, {topic_arn:'abcd:foo'}],
        [:list_topics, {}, {topics:[{topic_arn:'abcd:foo'}]}],
      ) }
      it "returns the topic" do
        expect(
          described_class.ensure_topic('foo')
        ).to descend_match topic_arn: 'abcd:foo'
      end
    end
  end

  describe '#retrieve_subscription' do
    # Mock up a topic. (We should really use the SNS topic provided by AWS-SDK.)
    let (:topic) { OpenStruct.new(topic_arn: 'abcd:foo') }
    let (:endpoint) { 'place.com' }

    context "when it doesn't exist" do
      before { stub_calls(
        [:list_subscriptions_by_topic, {topic_arn: 'abcd:foo'}, {subscriptions:[]}],
      ) }
      it "returns nil" do
        expect(
          described_class.retrieve_subscription(topic, endpoint)
        ).to be nil
      end
    end

    context "when it exists alone" do
      before { stub_calls(
        [
          :list_subscriptions_by_topic,
          {topic_arn: 'abcd:foo'},
          {subscriptions:[
            { protocol: 'https', endpoint: endpoint },
          ]}
        ],
      ) }
      it "returns the subscription" do
        expect(
          described_class.retrieve_subscription(topic, endpoint)
        ).to descend_match endpoint: endpoint, protocol: 'https'
      end
      it "returns the subscription when specifying protocol" do
        expect(
          described_class.retrieve_subscription(topic, endpoint, 'https')
        ).to descend_match endpoint: endpoint, protocol: 'https'
      end
      it "returns nil when specifying the wrong protocol" do
        expect(
          described_class.retrieve_subscription(topic, endpoint, 'http')
        ).to be nil
      end
    end

    context "when multiples exist" do
      before { stub_calls(
        [
          :list_subscriptions_by_topic,
          {topic_arn: 'abcd:foo'},
          {subscriptions:[
            { protocol: 'https', endpoint: endpoint, owner: 'John' },
            { protocol: 'http', endpoint: endpoint, owner: 'Jane' },
          ]}
        ],
      ) }

      it "returns the right subscription" do
        expect(
          described_class.retrieve_subscription(topic, endpoint)
        ).to descend_match protocol: 'https', owner: 'John'
      end
      it "returns the right subscription when specifying https" do
        expect(
          described_class.retrieve_subscription(topic, endpoint, 'https')
        ).to descend_match protocol: 'https', owner: 'John'
      end
      it "returns the right subscription when specifying http" do
        expect(
          described_class.retrieve_subscription(topic, endpoint, 'http')
        ).to descend_match protocol: 'http', owner: 'Jane'
      end
    end
  end

  describe '#ensure_subscription' do
    # Mock up a topic. (We should really use the SNS topic provided by AWS-SDK.)
    let (:topic) { OpenStruct.new(topic_arn: 'abcd:foo') }
    let (:endpoint) { 'place.com' }

    context "when it already exists" do
      before { stub_calls(
        [
          :list_subscriptions_by_topic,
          {topic_arn: 'abcd:foo'},
          {subscriptions:[
            { protocol: 'https', endpoint: endpoint },
          ]}
        ],
      ) }
      it "returns the subscription" do
        expect(
          described_class.ensure_subscription(topic, endpoint)
        ).to descend_match endpoint: endpoint, protocol: 'https'
      end
      it "returns the subscription when specifying protocol" do
        expect(
          described_class.ensure_subscription(topic, endpoint, 'https')
        ).to descend_match endpoint: endpoint, protocol: 'https'
      end
    end

    context "when it doesn't exist" do
      before { stub_calls(
        [
          :list_subscriptions_by_topic,
          {topic_arn: 'abcd:foo'},
          {subscriptions:[]}
        ],
        [
          :subscribe,
          {topic_arn: 'abcd:foo', protocol: 'https', endpoint: endpoint},
          {subscription_arn: 'foo:bar:baz'},
        ],
        [
          :list_subscriptions_by_topic,
          {topic_arn: 'abcd:foo'},
          {subscriptions:[
            { protocol: 'https', endpoint: endpoint },
          ]}
        ],
      ) }
      it "returns the subscription" do
        expect(
          described_class.ensure_subscription(topic, endpoint)
        ).to descend_match endpoint: endpoint, protocol: 'https'
      end
      it "returns the subscription when specifying protocol" do
        expect(
          described_class.ensure_subscription(topic, endpoint, 'https')
        ).to descend_match endpoint: endpoint, protocol: 'https'
      end
    end
  end
end
