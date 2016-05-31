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
end
