describe GhostChef::IAM do
  include_context :service

  let(:role_name) { 'some role' }

  def role_response(role_name)
    {
      role: {
        role_name: role_name,
        role_id: 'abcd',
        arn: 'some:arn:for:me',
        create_date: Time.now,
        path: '/some/path',
      }
    }
  end

  describe '#retrieve_role' do
    context "when the role doesn't exist" do
      before { stub_calls([:get_role, {role_name: role_name}, 'NoSuchEntity']) }
      it 'returns nil' do
        expect(described_class.retrieve_role(role_name)).to be nil
      end
    end

    context 'when the role exists' do
      before { stub_calls([:get_role, {role_name: role_name}, role_response(role_name)]) }
      it 'returns the role' do
        expect(described_class.retrieve_role(role_name)).to descend_match(
          role_name: role_name
        )
      end
    end
  end

  describe '#retrieve_attached_policies' do
    let(:role) { Aws::IAM::Types::Role.new(role_name: role_name) }

    context 'when the role has no attached policies' do
      before {stub_calls([:list_attached_role_policies, {role_name: role_name}, []])}
      it "returns an empty hash" do
        expect(described_class.retrieve_attached_policies(role)).to eql({})
      end
    end

    context 'when the role has 1 attached policies' do
      before {stub_calls(
        [:list_attached_role_policies, {role_name: role_name}, {
          attached_policies: [
            { policy_arn: 'arn:p1', policy_name: 'p1' },
          ]
        }]
      )}
      it "returns 1 policy mapping" do
        expect(described_class.retrieve_attached_policies(role)).to eql({
          'p1' => 'arn:p1',
        })
      end
    end

    context 'when the role has 1+1 attached policies' do
      before {stub_calls(
        [:list_attached_role_policies, {role_name: role_name}, {
          attached_policies: [
            { policy_arn: 'arn:p1', policy_name: 'p1' },
          ],
          is_truncated: true,
          marker: 'abcd',
        }],
        [:list_attached_role_policies, {role_name: role_name, marker: 'abcd'}, {
          attached_policies: [
            { policy_arn: 'arn:p2', policy_name: 'p2' },
          ],
        }],
      )}
      it "returns 1 policy mapping" do
        expect(described_class.retrieve_attached_policies(role)).to eql({
          'p1' => 'arn:p1',
          'p2' => 'arn:p2',
        })
      end
    end

    context 'when the role has 1+1+1 attached policies' do
      before {stub_calls(
        [:list_attached_role_policies, {role_name: role_name}, {
          attached_policies: [
            { policy_arn: 'arn:p1', policy_name: 'p1' },
          ],
          is_truncated: true,
          marker: 'abcd',
        }],
        [:list_attached_role_policies, {role_name: role_name, marker: 'abcd'}, {
          attached_policies: [
            { policy_arn: 'arn:p2', policy_name: 'p2' },
          ],
          is_truncated: true,
          marker: 'efgh',
        }],
        [:list_attached_role_policies, {role_name: role_name, marker: 'efgh'}, {
          attached_policies: [
            { policy_arn: 'arn:p3', policy_name: 'p3' },
          ],
        }],
      )}
      it "returns 1 policy mapping" do
        expect(described_class.retrieve_attached_policies(role)).to eql({
          'p1' => 'arn:p1',
          'p2' => 'arn:p2',
          'p3' => 'arn:p3',
        })
      end
    end
  end
end
