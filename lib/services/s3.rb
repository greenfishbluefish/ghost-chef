class S3
  @@client ||= Aws::S3::Client.new

  def self.bucket_exists(name)
    @@client.head_bucket(
      bucket: name,
    )
    true
  rescue Aws::S3::Errors::Forbidden,
    Aws::S3::Errors::NotFound
      false
  end

  def self.ensure_bucket(name, opts={})
    unless self.bucket_exists(name)
      @@client.create_bucket(
        bucket: name,
        acl: opts[:acl] || 'public-read',
      )
    end
    true
  end

  def self.enable_website(name, opts={})
    config = {}

    if opts[:error]
      config[:error_document] = { key: opts[:error] }
    end
    if opts[:index]
      config[:index_document] = { suffix: opts[:index] }
    end

    @@client.put_bucket_website(
      bucket: name,
      website_configuration: config,
    )
  end

  def self.upload(name, opts={})
    raise "Must provide filename to S3.upload()" unless opts[:filename]

    @@client.put_object(
      bucket: name,
      key: opts[:filename],
      body: opts[:contents] || '',
      acl: opts[:acl] || 'public-read',
    )

    true
  end
end
