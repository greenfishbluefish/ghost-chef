class Certificates
  @@client ||= Aws::ACM::Client.new

  def self.filter(method, args, key, &filter)
    Util.filter(
      @@client, method, args, key, [:next_token, :next_token], &filter
    )
  end

  def self.retrieve_certificate(domain)
    filter(:list_certificates, {}, :certificate_summary_list) do |cert|
      cert.domain_name == domain
    end.first
  end

  def self.ensure_certificate(domain, validation_domain=domain)
    cert = retrieve_certificate(domain)
    unless cert
      cert = @@client.request_certificate(
        domain_name: domain,
        domain_validation_options: [
          {
            domain_name: domain,
            validation_domain: validation_domain,
          },
        ],
      )
      puts "A SSL certificate has been requested."
      puts "You must wait for that to be approved before continuing"
      require 'pp'
      pp cert
      exit 1
    end
    cert
  end
end
