class Certificates
  @@client ||= Aws::ACM::Client.new

  def self.retrieve_certificate(domain)
    filter(@@client, :list_certificates, {}, :certificate_summary_list) do |cert|
      cert.domain_name == domain
    end.first
  end

  def self.ensure_certificate(domain)
    cert = retrieve_certificate(domain)
    unless cert
      cert = @@client.request_certificate(
        domain_name: domain,
        domain_validation_options: [
          {
            domain_name: domain,
            validation_domain: 'cyanna.com',
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
