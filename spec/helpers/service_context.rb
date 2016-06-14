shared_context :service do
  let(:client) { described_class.class_variable_get('@@client') }
end
