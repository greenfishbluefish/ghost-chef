describe GhostChef::Certificates do
  let(:client) { described_class.class_variable_get('@@client') }

  context '#retrieve_certificate' do
    context "with no certificates" do
      before {
        stub_calls([:list_certificates, {}, {certificate_summary_list: []}])
      }
      it 'finds nothing' do
        expect(described_class.retrieve_certificate('foo.com')).to be_falsy
      end
    end

    context "with one certificate" do
      before {
        stub_calls([:list_certificates, {}, {
          certificate_summary_list: [
            { domain_name: 'foo.com' },
          ],
        }])
      }
      it "finds nothing searching for the wrong one" do
        expect(described_class.retrieve_certificate('bar.com')).to be_falsy
      end
      it "finds something searching for the right one" do
        expect(
          described_class.retrieve_certificate('foo.com').domain_name
        ).to eql 'foo.com'
      end
    end

    context "with two certificates" do
      before {
        stub_calls([:list_certificates, {}, {
          certificate_summary_list: [
            { domain_name: 'foo.com' },
            { domain_name: 'foo2.com' },
          ],
        }])
      }
      it "finds nothing searching for the wrong one" do
        expect(described_class.retrieve_certificate('bar.com')).to be_falsy
      end
      it "finds something searching for the right one" do
        expect(
          described_class.retrieve_certificate('foo.com').domain_name
        ).to eql 'foo.com'
      end
    end
  end

  context '#ensure_certificate' do
    context "when the certificate already exists" do
      before {
        stub_calls([:list_certificates, {}, {
          certificate_summary_list: [
            { domain_name: 'foo.com' },
          ],
        }])
      }

      it "does not call #request_certificate" do
        expect(client).to_not receive(:request_certificate)
        expect(described_class.ensure_certificate('foo.com')).to be_truthy
      end
    end

    context "when the certificate does not already exist" do
      context "when another certificate exists" do
        before {
          stub_calls([:list_certificates, {}, {
            certificate_summary_list: [
              { domain_name: 'bar.com' },
            ],
          }])
        }

        it "calls #request_certificate" do
          stub_calls([:request_certificate, {
            domain_name: 'foo.com',
            domain_validation_options: [
              {
                domain_name: 'foo.com',
                validation_domain: 'foo.com',
              },
            ],
          }, {}])

          expect{
            begin described_class.ensure_certificate('foo.com')
            rescue SystemExit => e
              expect(e.status).to eql 1
            end
          }.to output(/A SSL certificate has been requested/).to_stdout
        end
      end

      context "when another certificate does not exist" do
        before {
          stub_calls([:list_certificates, {}, {
            certificate_summary_list: [],
          }])
        }

        it "calls #request_certificate" do
          stub_calls([:request_certificate, {
            domain_name: 'foo.com',
            domain_validation_options: [
              {
                domain_name: 'foo.com',
                validation_domain: 'foo.com',
              },
            ],
          }, {}])

          expect{
            begin described_class.ensure_certificate('foo.com')
            rescue SystemExit => e
              expect(e.status).to eql 1
            end
          }.to output(/A SSL certificate has been requested/).to_stdout
        end

        it "calls #request_certificate with a validation_domain" do
          stub_calls([:request_certificate, {
            domain_name: 'foo.com',
            domain_validation_options: [
              {
                domain_name: 'foo.com',
                validation_domain: 'bar.com',
              },
            ],
          }, {}])

          expect{
            begin described_class.ensure_certificate('foo.com', 'bar.com')
            rescue SystemExit => e
              expect(e.status).to eql 1
            end
          }.to output(/A SSL certificate has been requested/).to_stdout
        end
      end
    end
  end
end
