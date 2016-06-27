describe GhostChef::LoadBalancer do
  include_context :service

  def elb_response(name)
    {
      load_balancer_name: name,
    }
  end

  context '#retrieve_elb' do
    context "when the ELB doesn't exist" do
      before { stub_calls(
        [:describe_load_balancers, {load_balancer_names: ['abcd']}, {load_balancer_descriptions:[]}],
      ) }
      it 'returns nil' do
        expect(described_class.retrieve_elb('abcd')).to be nil
      end
    end

    context 'when the ELB exists' do
      before { stub_calls(
        [:describe_load_balancers, {load_balancer_names: ['abcd']}, {load_balancer_descriptions:[elb_response('abcd')]}],
      ) }
      it 'returns the ELB' do
        expect(described_class.retrieve_elb('abcd')).to descend_match(
          load_balancer_name: 'abcd',
        )
      end
    end
  end

  context '#ensure_elb' do
  end

  context 'ensure_instances_in_service' do
  end

  context '#ensure_instances_detached' do
  end
end
