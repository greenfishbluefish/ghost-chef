##
# This class manages all interaction with SNS, Amazon's Notification service.
class GhostChef::Notifications
  @@client ||= Aws::SNS::Client.new

  ##
  # This method will retrieve a SNS topic given a name. This topic is used in
  # most other methods.
  #
  # In general, use ensure_topic() instead of this method.
  def self.retrieve_topic(name)
    filter(:list_topics, {}, :topics) do |item|
      item.topic_arn.match(/:#{name}$/)
    end.first
  end

  ##
  # This method will, given a name, ensure the SNS topic exists. This topic is
  # used in most other methods. If the topic does not exist, it will be created.
  def self.ensure_topic(name)
    topic = retrieve_topic(name)
    unless topic
      @@client.create_topic(name: name)
      topic = retrieve_topic(name)
    end
    topic
  end

  ##
  # This method will retrieve a SNS subscription, given a topic and an endpoint.
  # There is an optional protocol which defaults to 'https'.
  #
  # In general, use ensure_subscription() instead of this method.
  def self.retrieve_subscription(topic, endpoint, protocol='https')
    filter(
      :list_subscriptions_by_topic, {topic_arn: topic.topic_arn},
      :subscriptions,
    ) do |s|
      s.endpoint == endpoint && s.protocol == protocol
    end.first
  end

  ##
  # This method will ensure a SNS subscription exists, given a topic and an
  # endpoint. There is an optional protocol which defaults to 'https'. If the
  # subscription does not exist, it will be created.
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

  private

  def self.filter(method, args, key, &filter)
    GhostChef::Util.filter(
      @@client, method, args, key, [:next_token, :next_token], &filter
    )
  end
end
