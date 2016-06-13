class GhostChef::Notifications
  @@client ||= Aws::SNS::Client.new

  def self.filter(method, args, key, &filter)
    GhostChef::Util.filter(
      @@client, method, args, key, [:next_token, :next_token], &filter
    )
  end

  def self.retrieve_topic(name)
    filter(:list_topics, {}, :topics) do |item|
      item.topic_arn.match(/:#{name}$/)
    end.first
  end

  def self.ensure_topic(name)
    topic = retrieve_topic(name)
    unless topic
      @@client.create_topic(name: name)
      topic = retrieve_topic(name)
    end
    topic
  end

  def self.retrieve_subscription(topic, endpoint, protocol='https')
    filter(
      :list_subscriptions_by_topic,
      {topic_arn: topic.topic_arn},
      :subscriptions,
    ) do |s|
      s.endpoint == endpoint && s.protocol == protocol
    end.first
  end
  def self.ensure_subscription(topic, endpoint, protocol='https')
    subscription = retrieve_subscription(topic, endpoint, protocol)
    unless subscription
      @@client.subscribe(
        topic_arn: topic.topic_arn,
        protocol: protocol,
        endpoint: endpoint,
      )
      subscription = retrieve_subscription(topic, endpoint, protocol)

      # Need to block until the subscription has been confirmed.
      # or throw an error after a specific amount of time.
    end

    subscription
  end
end
