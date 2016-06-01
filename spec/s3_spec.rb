describe S3 do
  let(:client) { S3.class_variable_get('@@client') }

  describe '#bucket_exists' do
    context 'finds the bucket' do
      before(:each) { client.stub_responses(:head_bucket, {}) }
      it { expect(S3.bucket_exists('bucket')).to be true }
    end
    context 'finds no bucket' do
      before(:each) { client.stub_responses(:head_bucket, 'NotFound') }
      it { expect(S3.bucket_exists('bucket')).to be false }
    end
    context 'cannot see the bucket' do
      before(:each) { client.stub_responses(:head_bucket, 'Forbidden') }
      it { expect(S3.bucket_exists('bucket')).to be false }
    end
    context 'times out' do
      before(:each) { client.stub_responses(:head_bucket, 'TimedOut') }
      it {
        expect {
          S3.bucket_exists('bucket')
        }.to raise_error Aws::S3::Errors::TimedOut
      }
    end
  end

  describe '#ensure_bucket' do
    context 'bucket exists' do
      before(:each) { client.stub_responses(:head_bucket, {}) }
      it { expect(S3.ensure_bucket('bucket')).to be true }
    end
    context 'bucket does not exist' do
      before(:each) {
        client.stub_responses(:head_bucket, 'NotFound')
        client.stub_responses(:create_bucket, {location: 'some-place'})
      }
      it { expect(S3.ensure_bucket('bucket')).to be true }
    end
    context 'cannot create a bucket' do
      before(:each) {
        client.stub_responses(:head_bucket, 'Forbidden')
        client.stub_responses(:create_bucket, 'Forbidden')
      }
      it { expect{S3.ensure_bucket('bucket')}.to raise_error Aws::S3::Errors::Forbidden}
    end
  end

  describe '#upload' do
    it 'throws an error without a filename' do
      expect {
        S3.upload('bucket')
      }.to raise_error "Must provide filename to S3.upload()"
    end

    it 'returns true with a empty file' do
      expect(client).to receive(:put_object)
        .with(
          bucket: 'bucket',
          key: 'foo',
          body: '',
          acl: 'public-read',
        ).and_call_original

      expect(
        S3.upload('bucket', filename: 'foo')
      ).to be true
    end

    it 'returns true with a file that has content' do
      expect(client).to receive(:put_object)
        .with(
          bucket: 'bucket',
          key: 'foo',
          body: 'abcd',
          acl: 'public-read',
        ).and_call_original

      expect(
        S3.upload('bucket', filename: 'foo', contents: 'abcd')
      ).to be true
    end

    it 'returns true with a file that has content and an ACL' do
      expect(client).to receive(:put_object)
        .with(
          bucket: 'bucket',
          key: 'foo',
          body: 'abcd',
          acl: 'public-write',
        ).and_call_original

      expect(
        S3.upload('bucket', filename: 'foo', contents: 'abcd', acl: 'public-write')
      ).to be true
    end
  end

  describe '#enable_website' do
    before(:each) { client.stub_responses(:put_bucket_website, {}) }
    it 'with defaults' do
      expect(client).to receive(:put_bucket_website)
        .with(
          bucket: 'bucket',
          website_configuration: {
            index_document: { suffix: 'index.html' },
          },
        ).and_call_original
      expect(S3.enable_website('bucket')).to be true
    end

    it 'setting index document' do
      expect(client).to receive(:put_bucket_website)
        .with(
          bucket: 'bucket',
          website_configuration: {
            index_document: { suffix: 'index.htm' },
          },
        ).and_call_original
      expect(S3.enable_website('bucket', index: 'index.htm')).to be true
    end

    it 'setting error document' do
      expect(client).to receive(:put_bucket_website)
        .with(
          bucket: 'bucket',
          website_configuration: {
            index_document: { suffix: 'index.html' },
            error_document: { key: 'error.html' },
          },
        ).and_call_original
      expect(S3.enable_website('bucket', error: 'error.html')).to be true
    end
  end
end
