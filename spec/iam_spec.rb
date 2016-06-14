describe GhostChef::IAM do
  let(:client) { described_class.class_variable_get('@@client') }
  let(:role) { 'some role' }

  def create_role(name)
    {
      role: {
        role_name: name,
        role_id: 'abcd',
        arn: 'some:arn:for:me',
        create_date: Time.now,
        path: '/some/path',
      }
    }
  end

  describe '#retrieve_role' do
    context "when the role doesn't exist" do
      before { stub_calls([:get_role, {role_name: role}, 'NoSuchEntity']) }
      it 'returns nil' do
        expect(described_class.retrieve_role(role)).to be nil
      end
    end

    context 'when the role exists' do
      before { stub_calls([:get_role, {role_name: role}, create_role(role)]) }
      it 'returns the role' do
        expect(described_class.retrieve_role(role)).to descend_match(
          role_name: role
        )
      end
    end
  end

  describe '#retrieve_attached_policies' do
    context 'when the role has no attached policies' do
    end

    context 'when the role has 1 attached policies' do
    end

    context 'when the role has 1+1 attached policies' do
    end

    context 'when the role has 1+1+1 attached policies' do
    end
  end
end
