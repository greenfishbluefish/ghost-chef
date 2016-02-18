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
end
