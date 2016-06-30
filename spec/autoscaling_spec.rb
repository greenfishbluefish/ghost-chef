describe GhostChef::AutoScaling do
  include_context :service

  def launch_configuration_response(name)
    {
      launch_configuration_name: name,
      image_id: 'abcd',
      instance_type: 't1.tiny',
      created_time: Time.now,
    }
  end

  context '#retrieve_launch_configuration' do
    context "when it doesn't exist" do
      before{stub_calls(
        [:describe_launch_configurations, {launch_configuration_names:['abcd']}, {launch_configurations:[]}],
      )}
      it "returns nil" do
        expect(described_class.retrieve_launch_configuration('abcd')).to be nil
      end
    end

    context "when it exists" do
      before{stub_calls(
        [:describe_launch_configurations, {launch_configuration_names:['abcd']}, {launch_configurations:[launch_configuration_response('abcd')]}],
      )}
      it "returns the launch configuration" do
        expect(described_class.retrieve_launch_configuration('abcd')).to descend_match(
          launch_configuration_name: 'abcd',
        )
      end
    end
  end

  context '#ensure_launch_configuration' do
    context "when it doesn't already exist" do
      before{stub_calls(
        [:describe_launch_configurations, {launch_configuration_names:['abcd']}, {launch_configurations:[]}],
        [:create_launch_configuration, {launch_configuration_name:'abcd'}, nil],
        [:describe_launch_configurations, {launch_configuration_names:['abcd']}, {launch_configurations:[launch_configuration_response('abcd')]}],
      )}
      it "returns a new launch configuration" do
        expect(described_class.ensure_launch_configuration('abcd')).to descend_match(
          launch_configuration_name: 'abcd',
        )
      end
    end

    context "when it already exists" do
      before{stub_calls(
        [:describe_launch_configurations, {launch_configuration_names:['abcd']}, {launch_configurations:[launch_configuration_response('abcd')]}],
      )}
      it "returns the existing launch configuration" do
        expect(described_class.ensure_launch_configuration('abcd')).to descend_match(
          launch_configuration_name: 'abcd',
        )
      end
    end
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
