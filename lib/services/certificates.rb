##
# This class manages all interaction with ACM, Amazon's Certificate service.
class GhostChef::Certificates
  @@client ||= Aws::ACM::Client.new

  ##
  # This method retrieves the certificate (if any) already created for the
  # domain provided. The domain name must be an exact match. If none match, then
  # nil will be returned.
  def self.retrieve_certificate(domain)
    filter(:list_certificates, {}, :certificate_summary_list) do |cert|
      cert.domain_name == domain
    end.first
  end

  ##
  # This method will ensure that a certificate is created for the domain
  # provided. It will search for the domain first, using retrieve_certificate().
  # If one isn't found, it will create one.
  #
  # Unlike all other AWS objects, creating a certificate for a domain requires a
  # manual activity which *cannot* be scripted per AWS mechanisms. You _must_
  # login as an owner of the domain (or validation_domain) and click the button
  # through the AWS interface. This only has to be done once per domain; the
  # certificate will auto-renew without requiring the manual step.
  #
  # If your validation domain is not the same as your domain, you can provide a
  # validation domain - q.v. the AWS documentation for details.
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

  private

  def self.filter(method, args, key, &filter)
    GhostChef::Util.filter(
      @@client, method, args, key, [:next_token, :next_token], &filter
    )
  end
end
