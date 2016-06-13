##
# This class manages all interaction with S3, Amazon's Storage service.
class GhostChef::S3
  @@client ||= Aws::S3::Client.new

  ##
  # Given a bucket name, this returns a Boolean for its existence.
  #
  # This method exists because Aws::S3::Client.head_bucket() throws different
  # errors on non-existence vs. returning false (more useful below).
  #
  # In general, use ensure_bucket() instead of this method.
  def self.bucket_exists(name)
    @@client.head_bucket(
      bucket: name,
    )
    true
  rescue Aws::S3::Errors::Forbidden,
    Aws::S3::Errors::NotFound
      false
  end

  ##
  # Given a bucket name, ensure that S3 bucket exists. If it does not exist,
  # attempt to create it using the opts provided.
  #
  # The opts can contain:
  # * acl: The access controls for this bucket
  #   * Legal values are: (q.v. AWS documentation for more details)
  #     * 'private'
  #     * 'public-read'
  #     * 'public-read-write'
  #     * 'authenticated-read'
  #   * This will default to 'private' (*DIFFERENT* from Aws::S3::Client)
  #
  # This method will always return true.
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

  ##
  # Given a bucket name, this method will enable the bucket to host a website
  # per AWS's mechanisms. (q.v. AWS documentation for more details)
  #
  # The ops can contain:
  # * index: This is the name of the index document served by default.
  #   * This will default to 'index.html'
  # * error: This is the name of the document served when an error occurs.
  #   * This has no default value.
  #
  # This method will always return true.
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

  ##
  # Given a filename and options, this will put an object into the specified
  # bucket with the provided filename. This wraps Aws::S3::Client.put_object()
  # with a better interface and useful defaults.
  #
  # The opts can contain:
  # * contents: These are the contents of the file. This defaults to "".
  # * acl: The access controls for this object (subject to the bucket ACL)
  #   * Legal values are: (q.v. AWS documentation for more details)
  #     * 'private'
  #     * 'public-read'
  #     * 'public-read-write'
  #     * 'authenticated-read'
  #   * This will default to 'private' (*DIFFERENT* from Aws::S3::Client)
  #
  # This method will always return true.
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
