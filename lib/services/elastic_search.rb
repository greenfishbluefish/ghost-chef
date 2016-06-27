##
# This class manages all interaction with ElasticSearch, Amazon's ES service.
class GhostChef::ElasticSearch
  @@client ||= Aws::ElasticsearchService::Client.new

  ##
  # Given a domain name, this returns the AWS ElasticSearch instance for that
  # domain. If it doesn't exist, this will return nil.
  #
  # If it is being deleted, this will raise a GhostChef::Error.
  #
  # In general, use ensure() instead of this method.
  def self.retrieve(domain_name)
    es_domain = @@client.describe_elasticsearch_domain(
      domain_name: domain_name
    ).domain_status

    #TODO: what to do in this case? 
    raise GhostChef::Error, "This domain is currently being deleted" if es_domain.deleted

    es_domain
  rescue Aws::ElasticsearchService::Errors::ResourceNotFoundException
    nil
  end

  ##
  # Given a domain name, this returns the AWS ElasticSearch instance for that
  # domain. If it doesn't exist, this will create it using the provided opts.
  def self.ensure(domain_name, opts = {})
    domain = retrieve(domain_name)
    unless domain
      @@client.create_elasticsearch_domain(
        **opts.merge(domain_name: domain_name)
      )

      domain = retrieve(domain_name)
    end
    domain
  end

  ##
  # Unlike most clients, the Aws::ElasticsearchService::Client does not define
  # any waiters. This means we have to create our own waiter. This waiter is
  # specifically created to ensure a given ElasticSearch domain has an active
  # and available endpoint. This also means the ElasticSearch object has stopped
  # processing.
  #
  # Given a domain_name, this method will block until the associated domain
  # is ready for usage. It will sleep for 30 seconds between iterations.
  def self.ensure_endpoint_available(domain_name)
    domain = retrieve(domain_name) or raise GhostChef::Error, "Domain does not exist"

    # wait until processing is completed
    # Endpoint won't be available until then
    while domain.processing || !domain.endpoint
      puts "Elasticsearch domain is still processing..."
      sleep 30

      # Re-retrieve the domain object to refresh it.
      domain = retrieve(domain_name)
    end

    domain.endpoint
  end
end
