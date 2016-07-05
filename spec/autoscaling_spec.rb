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

  def auto_scaling_group_response(name)
    {
      auto_scaling_group_name: name,
      min_size: 1,
      max_size: 1,
      desired_capacity: 1,
      default_cooldown: 1,
      availability_zones: [],
      health_check_type: 'none',
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
    context "when looking by name" do
      context "when it doesn't exist" do
        before{stub_calls(
          [:describe_auto_scaling_groups, {auto_scaling_group_names:['abcd']}, {auto_scaling_groups:[]}],
        )}
        it "returns nil" do
          expect(described_class.retrieve_auto_scaling_groups(name: 'abcd')).to be nil
        end
      end

      context "when it exists" do
        before{stub_calls(
          [:describe_auto_scaling_groups, {auto_scaling_group_names:['abcd']}, {auto_scaling_groups:[auto_scaling_group_response('abcd')]}],
        )}
        it "returns the auto scaling group" do
          expect(described_class.retrieve_auto_scaling_groups(name: 'abcd')).to descend_match(
            auto_scaling_group_name: 'abcd',
          )
        end
      end
    end

    context "when looking by min_size" do
      context "when it doesn't exist" do
        before{stub_calls(
          [:describe_auto_scaling_groups, {max_records: 100}, {auto_scaling_groups:[]}],
        )}
        it "returns []" do
          expect(described_class.retrieve_auto_scaling_groups(min_size: 1)).to eql []
        end
      end

      context "when it exists" do
        before{stub_calls(
          [:describe_auto_scaling_groups, {max_records: 100}, {auto_scaling_groups:[auto_scaling_group_response('abcd')]}],
        )}
        it "returns the auto scaling group" do
          expect(described_class.retrieve_auto_scaling_groups(min_size: 1)[0]).to descend_match(
            auto_scaling_group_name: 'abcd',
          )
        end
      end
    end
  end

  context '#ensure_auto_scaling_group' do
    context "when it doesn't exist" do
      before{stub_calls(
        [:describe_auto_scaling_groups, {auto_scaling_group_names:['abcd']}, {auto_scaling_groups:[]}],
        [:create_auto_scaling_group, {auto_scaling_group_name:'abcd', min_size: 1, max_size: 1}, nil],
        [:describe_auto_scaling_groups, {auto_scaling_group_names:['abcd']}, {auto_scaling_groups:[auto_scaling_group_response('abcd')]}],
      )}
      it "returns the new auto scaling group" do
        expect(described_class.ensure_auto_scaling_group('abcd', min_size: 1, max_size: 1)).to descend_match(
          auto_scaling_group_name: 'abcd',
        )
      end
    end

    context "when it exists" do
      before{stub_calls(
        [:describe_auto_scaling_groups, {auto_scaling_group_names:['abcd']}, {auto_scaling_groups:[auto_scaling_group_response('abcd')]}],
      )}
      it "returns the auto scaling group" do
        expect(described_class.ensure_auto_scaling_group('abcd')).to descend_match(
          auto_scaling_group_name: 'abcd',
        )
      end
    end
  end

  context '#destroy_auto_scaling_group' do
    let(:instances) { nil }
    let(:asg) { Aws::AutoScaling::Types::AutoScalingGroup.new(auto_scaling_group_name: 'asg:abcd', instances: instances) }

    context "without instances" do
      let(:instances) {[]}

      before {stub_calls(
        [:describe_auto_scaling_groups, {auto_scaling_group_names:['asg:abcd']}, {auto_scaling_groups:[auto_scaling_group_response('asg:abcd')]}],
        [:delete_auto_scaling_group, {
          auto_scaling_group_name: 'asg:abcd', force_delete: true,
        }, nil],
      )}

      it "destroys the ASG, by name" do
        expect(GhostChef::Compute).not_to receive(:waitfor_all_instances_terminated)
        expect(described_class.destroy_auto_scaling_group(asg.auto_scaling_group_name)).to be true
      end
    end

    context "with instances" do
      let(:instances) { [1] }

      before {stub_calls(
        [:delete_auto_scaling_group, {
          auto_scaling_group_name: 'asg:abcd', force_delete: true,
        }, nil],
      )}

      it "destroys the ASG, by object" do
        expect(GhostChef::Compute).to receive(:waitfor_all_instances_terminated)
        expect(described_class.destroy_auto_scaling_group(asg)).to be true
      end
    end
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
