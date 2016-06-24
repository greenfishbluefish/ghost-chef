describe GhostChef::IAM do
  include_context :service

  let(:role_name) { 'some role' }
  let(:instance_profile_name) { 'some instance profile' }

  def role_response(name)
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

  def instance_profile_response(name)
    {
      instance_profile: {
        instance_profile_name: name,
        instance_profile_id: 'abcd',
        arn: 'some:arn:for:me',
        create_date: Time.now,
        path: '/some/path',
        roles: [],
      }
    }
  end

  def attached_policies_response(policy_names, addl={})
    return {
      attached_policies: policy_names.map {|n| {
        policy_name: n, policy_arn: "arn:aws:iam::aws:policy/#{n}",
      }},
    }.merge(addl)
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

  describe '#ensure_role' do
    context "when the role doesn't exist" do
      before {
        role_policy = described_class.role_policy
        stub_calls(
          [:get_role, {role_name: role_name}, 'NoSuchEntity'],
          [:create_role, {role_name: role_name, assume_role_policy_document: role_policy}, role_response(role_name)],
        )
      }
      it 'returns a role' do
        expect(described_class.ensure_role(role_name)).to descend_match(
          role_name: role_name,
        )
      end
    end

    context 'when the role exists' do
      before {
        role_policy = described_class.role_policy
        stub_calls(
          [:get_role, {role_name: role_name}, role_response(role_name)],
          [:update_assume_role_policy, {role_name: role_name, policy_document: role_policy}, nil],
        )
      }
      it 'returns the role' do
        expect(described_class.ensure_role(role_name)).to descend_match(
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
        [:list_attached_role_policies, {role_name: role_name}, attached_policies_response(['p1']), ]
      )}
      it "returns 1 policy mapping" do
        expect(described_class.retrieve_attached_policies(role)).to eql({
          'p1' => 'arn:aws:iam::aws:policy/p1',
        })
      end
    end

    context 'when the role has 1+1 attached policies' do
      before {stub_calls(
        [:list_attached_role_policies, {role_name: role_name}, attached_policies_response(['p1'], is_truncated: true, marker: 'abcd')],
        [:list_attached_role_policies, {role_name: role_name, marker: 'abcd'}, attached_policies_response(['p2'])],
      )}
      it "returns 1 policy mapping" do
        expect(described_class.retrieve_attached_policies(role)).to eql({
          'p1' => 'arn:aws:iam::aws:policy/p1',
          'p2' => 'arn:aws:iam::aws:policy/p2',
        })
      end
    end

    context 'when the role has 1+1+1 attached policies' do
      before {stub_calls(
        [:list_attached_role_policies, {role_name: role_name},
          attached_policies_response(['p1'],
            is_truncated: true,
            marker: 'abcd',
        )],
        [:list_attached_role_policies, {role_name: role_name, marker: 'abcd'},
          attached_policies_response(['p2'],
            is_truncated: true,
            marker: 'efgh',
        )],
        [:list_attached_role_policies, {role_name: role_name, marker: 'efgh'},
          attached_policies_response(['p3']),
        ],
      )}
      it "returns 1 policy mapping" do
        expect(described_class.retrieve_attached_policies(role)).to eql({
          'p1' => 'arn:aws:iam::aws:policy/p1',
          'p2' => 'arn:aws:iam::aws:policy/p2',
          'p3' => 'arn:aws:iam::aws:policy/p3',
        })
      end
    end
  end

  describe '#ensure_attached_policies' do
    let(:role) { Aws::IAM::Types::Role.new(role_name: role_name) }

    context "when 0 attached" do
      before {stub_calls(
        [:list_attached_role_policies, {role_name: role_name}, []]
      )}
      context "when adding none" do
        it 'returns true' do
          expect(described_class.ensure_attached_policies(role, [])).to be true
        end
      end
      context "when adding 1" do
        before {stub_calls(
          [:attach_role_policy, {role_name: role_name, policy_arn: "arn:aws:iam::aws:policy/p1"}, nil]
        )}
        it 'returns true' do
          expect(described_class.ensure_attached_policies(role, ['p1'])).to be true
        end
      end
    end

    context "when 1 attached" do
      before {stub_calls(
        [:list_attached_role_policies, {role_name: role_name}, attached_policies_response(['p1']), ]
      )}
      context "when exact" do
        it 'returns true' do
          expect(described_class.ensure_attached_policies(role, ['p1'])).to be true
        end
      end
      context "when adding 1" do
        before {stub_calls(
          [:attach_role_policy, {role_name: role_name, policy_arn: "arn:aws:iam::aws:policy/p2"}, nil]
        )}
        it 'returns true' do
          expect(described_class.ensure_attached_policies(role, ['p1', 'p2'])).to be true
        end
      end
      context "when removing all" do
        before {stub_calls(
          [:detach_role_policy, {role_name: role_name, policy_arn: "arn:aws:iam::aws:policy/p1"}, nil]
        )}
        it 'returns true' do
          expect(described_class.ensure_attached_policies(role, [])).to be true
        end
      end
      context "when removing 1 and adding 1" do
        before {stub_calls(
          [:attach_role_policy, {role_name: role_name, policy_arn: "arn:aws:iam::aws:policy/p2"}, nil],
          [:detach_role_policy, {role_name: role_name, policy_arn: "arn:aws:iam::aws:policy/p1"}, nil],
        )}
        it 'returns true' do
          expect(described_class.ensure_attached_policies(role, ['p2'])).to be true
        end
      end
    end

    context "when 2 attached" do
      before {stub_calls(
        [:list_attached_role_policies, {role_name: role_name}, attached_policies_response(['p1', 'p2']), ]
      )}
      context "when exact" do
        it 'returns true' do
          expect(described_class.ensure_attached_policies(role, ['p1', 'p2'])).to be true
        end
      end
      context "when adding 1" do
        before {stub_calls(
          [:attach_role_policy, {role_name: role_name, policy_arn: "arn:aws:iam::aws:policy/p3"}, nil]
        )}
        it 'returns true' do
          expect(described_class.ensure_attached_policies(role, ['p1', 'p2', 'p3'])).to be true
        end
      end
      context "when removing 1" do
        before {stub_calls(
          [:detach_role_policy, {role_name: role_name, policy_arn: "arn:aws:iam::aws:policy/p1"}, nil]
        )}
        it 'returns true' do
          expect(described_class.ensure_attached_policies(role, ['p2'])).to be true
        end
      end
      context "when removing 1 and adding 1" do
        before {stub_calls(
          [:attach_role_policy, {role_name: role_name, policy_arn: "arn:aws:iam::aws:policy/p3"}, nil],
          [:detach_role_policy, {role_name: role_name, policy_arn: "arn:aws:iam::aws:policy/p1"}, nil],
        )}
        it 'returns true' do
          expect(described_class.ensure_attached_policies(role, ['p2', 'p3'])).to be true
        end
      end
      context "when removing all" do
        before {stub_calls(
          [:detach_role_policy, {role_name: role_name, policy_arn: "arn:aws:iam::aws:policy/p1"}, nil],
          [:detach_role_policy, {role_name: role_name, policy_arn: "arn:aws:iam::aws:policy/p2"}, nil],
        )}
        it 'returns true' do
          expect(described_class.ensure_attached_policies(role, [])).to be true
        end
      end
    end
  end

  describe '#retrieve_instance_profile' do
    context "when the profile doesn't exist" do
      before { stub_calls([:get_instance_profile, {instance_profile_name: instance_profile_name}, 'NoSuchEntity']) }
      it 'returns nil' do
        expect(described_class.retrieve_instance_profile(instance_profile_name)).to be nil
      end
    end

    context 'when the profile exists' do
      before { stub_calls([:get_instance_profile, {instance_profile_name: instance_profile_name}, instance_profile_response(instance_profile_name)]) }
      it 'returns the instance_profile' do
        expect(described_class.retrieve_instance_profile(instance_profile_name)).to descend_match(
          instance_profile_name: instance_profile_name
        )
      end
    end
  end

  describe '#ensure_instance_profile' do
  end

  describe '#retrieve_attached_roles' do
    let(:profile) { Aws::IAM::Types::InstanceProfile.new(instance_profile_name: 'abcd') }

    it 'has a name' do
      expect(profile).to descend_match(instance_profile_name: 'abcd')
    end
  end

  describe '#ensure_attached_roles' do
  end
end
