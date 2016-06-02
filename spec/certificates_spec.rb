describe Certificates do
  let(:client) { Certificates.class_variable_get('@@client') }

  context '#retrieve_certificate' do
    context "no certificates" do
      before(:each) {
        client.stub_responses(:list_certificates, {
          certificate_summary_list: []
        })
      }
      it { expect(Certificates.retrieve_certificate('foo.com')).to be nil }
		end

    context "one certificate" do
      before(:each) {
        client.stub_responses(:list_certificates, {
          certificate_summary_list: [
            { domain_name: 'foo.com' },
          ],
        })
      }
      it "searching for the wrong one" do
        expect(Certificates.retrieve_certificate('bar.com')).to be nil
      end
      it "searching for the right one" do
        expect(
          Certificates.retrieve_certificate('foo.com').domain_name
        ).to eql 'foo.com'
      end
		end

    context "two certificates" do
      before(:each) {
        client.stub_responses(:list_certificates, {
          certificate_summary_list: [
            { domain_name: 'foo.com' },
            { domain_name: 'foo2.com' },
          ],
        })
      }
      it "searching for the wrong one" do
        expect(Certificates.retrieve_certificate('bar.com')).to be nil
      end
      it "searching for the right one" do
        expect(
          Certificates.retrieve_certificate('foo.com').domain_name
        ).to eql 'foo.com'
      end
		end
	end

  context '#ensure_certificate' do
    context "certificate already exists" do
      before(:each) {
        client.stub_responses(:list_certificates, {
          certificate_summary_list: [
            { domain_name: 'foo.com' },
          ],
        })
      }

      it "does not call #request_certificate" do
				expect(client).to_not receive(:request_certificate)
        expect(Certificates.ensure_certificate('foo.com')).to be_truthy
      end
    end

    context "certificate does not already exist" do
      context "another certificate exists" do
				before(:each) {
					client.stub_responses(:list_certificates, {
						certificate_summary_list: [
							{ domain_name: 'bar.com' },
						],
					})
				}

				it "calls #request_certificate" do
					expect(client).to receive(:request_certificate)
            .with(
							domain_name: 'foo.com',
							domain_validation_options: [
								{
									domain_name: 'foo.com',
									validation_domain: 'foo.com',
								},
							],
            ).and_call_original

					expect{
            begin Certificates.ensure_certificate('foo.com')
            rescue SystemExit => e
							expect(e.status).to eql 1
            end
          }.to output(/A SSL certificate has been requested/).to_stdout
				end
      end

      context "another certificate does not exist" do
				before(:each) {
					client.stub_responses(:list_certificates, {
						certificate_summary_list: [
							{},
						],
					})
				}

				it "calls #request_certificate" do
					expect(client).to receive(:request_certificate)
            .with(
							domain_name: 'foo.com',
							domain_validation_options: [
								{
									domain_name: 'foo.com',
									validation_domain: 'foo.com',
								},
							],
            ).and_call_original

					expect{
            begin Certificates.ensure_certificate('foo.com')
            rescue SystemExit => e
							expect(e.status).to eql 1
            end
          }.to output(/A SSL certificate has been requested/).to_stdout
				end

				it "calls #request_certificate with a validation_domain" do
					expect(client).to receive(:request_certificate)
            .with(
							domain_name: 'foo.com',
							domain_validation_options: [
								{
									domain_name: 'foo.com',
									validation_domain: 'bar.com',
								},
							],
            ).and_call_original

					expect{
            begin Certificates.ensure_certificate('foo.com', 'bar.com')
            rescue SystemExit => e
							expect(e.status).to eql 1
            end
          }.to output(/A SSL certificate has been requested/).to_stdout
				end
      end
    end
	end
end
