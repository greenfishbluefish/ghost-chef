describe GhostChef::LoadBalancer do
  include_context :service

  def elb_response(name)
    { load_balancer_descriptions:[{load_balancer_name: name}] }
  end

  context '#retrieve_elb' do
    context "when the ELB doesn't exist" do
      before { stub_calls(
        [:describe_load_balancers, {load_balancer_names: ['abcd']}, 'LoadBalancerNotFound'],
      ) }
      it 'returns nil' do
        expect(described_class.retrieve_elb('abcd')).to be nil
      end
    end

    context 'when the ELB exists' do
      before { stub_calls(
        [:describe_load_balancers, {load_balancer_names: ['abcd']}, elb_response('abcd')],
      ) }
      it 'returns the ELB' do
        expect(described_class.retrieve_elb('abcd')).to descend_match(
          load_balancer_name: 'abcd',
        )
      end
    end
  end

  # TODO:
  # * validate listeners
  #   * with a ACM SSL cert
  # * validate tags
  # * validate security groups
  # * validate subnets
  context '#ensure_elb' do
    context "when the ELB doesn't exist" do
      before {
        stub_calls(
          [:describe_load_balancers, {load_balancer_names: ['abcd']}, 'LoadBalancerNotFound'],
          [:create_load_balancer, {load_balancer_name: 'abcd', listeners: []}, {dns_name: 'foo.bar.com'}],
          [:describe_load_balancers, {load_balancer_names: ['abcd']}, elb_response('abcd')],
        )
      }
      it 'returns the ELB' do
        expect(described_class.ensure_elb('abcd', [])).to descend_match(
          load_balancer_name: 'abcd',
        )
      end
    end

    context 'when the ELB exists' do
      before { stub_calls(
        [:describe_load_balancers, {load_balancer_names: ['abcd']}, elb_response('abcd')],
      ) }
      it 'returns the ELB' do
        expect(described_class.ensure_elb('abcd', [])).to descend_match(
          load_balancer_name: 'abcd',
        )
      end
    end
  end

  context '#waitfor_any_instance_available' do
  end

  context '#waitfor_all_instances_unavailable' do
  end
end
