describe S3 do
  let(:client) { S3.class_variable_get('@@client') }

  context '#bucket_exists' do
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

  context '#ensure_bucket' do
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
end
