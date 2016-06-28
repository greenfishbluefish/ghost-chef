describe GhostChef::AutoScaling do
  include_context :service

  context '#retrieve_launch_configuration' do
  end

  context '#ensure_launch_configuration' do
  end

  # Yes, groupS, not group.
  context '#retrieve_auto_scaling_groups' do
  end

  context '#ensure_auto_scaling_group' do
  end

  context '#destroy_auto_scaling_group' do
  end

  context '#detach_asg_from_elb' do
    let(:instances) { nil }
    let(:asg) { Aws::AutoScaling::Types::AutoScalingGroup.new(auto_scaling_group_name: 'asg:abcd', instances: instances) }
    let(:elb) { Aws::ElasticLoadBalancing::Types::LoadBalancerDescription.new(load_balancer_name: 'elb:abcd') }

    before {stub_calls(
      [:detach_load_balancers, {
        auto_scaling_group_name: 'asg:abcd',
        load_balancer_names: ['elb:abcd'],
      }, nil],
    )}

    context "without instances" do
      let(:instances) {[]}
      it "detaches the ASG from the ELB" do
        expect(GhostChef::LoadBalancer).not_to receive(:waitfor_all_instances_unavailable)
        expect(described_class.detach_asg_from_elb(asg,elb)).to be true
      end
    end

    context "with instances" do
      let(:instances) { [1] }
      it "detaches the ASG from the ELB" do
        expect(GhostChef::LoadBalancer).to receive(:waitfor_all_instances_unavailable)
        expect(described_class.detach_asg_from_elb(asg,elb)).to be true
      end
    end
  end
end
