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
        # ACL: private, public-read, public-read-write, authenticated-read
        acl: opts[:acl] || 'private',
      )
    end
    true
  end

  def self.enable_website(name, opts={})
    config = {}

    if opts[:index]
      config[:index_document] = { suffix: opts[:index] }
    else
      config[:index_document] = { suffix: 'index.html' }
    end

    if opts[:error]
      config[:error_document] = { key: opts[:error] }
    end

    @@client.put_bucket_website(
      bucket: name,
      website_configuration: config,
    )
    true
  end

  def self.upload(name, filename, opts={})
    @@client.put_object(
      bucket: name,
      key: filename,
      body: opts[:contents] || '',
      acl: opts[:acl] || 'private',
    )

    true
  end
end
