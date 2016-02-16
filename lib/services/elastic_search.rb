

class ElasticSearch

  @@client ||= Aws::ElasticsearchService::Client.new

  def self.retrieve(domain_name)
    es_domain = @@client.describe_elasticsearch_domain({
        domain_name: domain_name,
      })

    #TODO: what to do in this case? 
    raise "This domain is currently being deleted" if es_domain.domain_status.deleted

    es_domain
    rescue Aws::ElasticsearchService::Errors::ResourceNotFoundException
      false
  end

  def self.create(domain_name, opts = {})
    opts = opts.merge(domain_name: domain_name)

    @@client.create_elasticsearch_domain(opts)

    puts "Elasticsearch domain created."
    self.retrieve(domain_name)
  end

  def self.ensure(domain_name, opts = {})
    es_domain = self.retrieve(domain_name)
    
    if es_domain
      puts "Elasticsearch domain #{domain_name} already created"
    else
      es_domain = self.create(domain_name, opts = {})
    end
  end

  def self.ensure_endpoint_available(domain_name)
    # wait until processing is completed
    # Endpoint won't be available until then
    while self.processing?(domain_name) || !self.endpoint_available?(domain_name)
      puts "Elasticsearch domain is still processing..."
      sleep 30
    end

    self.endpoint(domain_name)
  end

  def self.processing?(domain_name)
    es_domain = self.retrieve(domain_name)
    raise "Elasticsearch domain not found" unless es_domain

    es_domain.domain_status.processing
  end

  def self.endpoint_available?(domain_name)
    !self.endpoint(domain_name).nil?
  end

  def self.endpoint(domain_name)
    es_domain = self.retrieve(domain_name)
    raise "Elasticsearch domain not found" unless es_domain

    es_domain.domain_status.endpoint
  end

end
