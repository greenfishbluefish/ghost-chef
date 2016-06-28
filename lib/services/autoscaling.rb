##
# This class manages all interaction with ELB, Amazon's Load Balancer service.
class GhostChef::AutoScaling
  @@client ||= Aws::AutoScaling::Client.new

  def self.detach_asg_from_elb(asg, elb)
    @@client.detach_load_balancers(
      auto_scaling_group_name: asg.auto_scaling_group_name,
      load_balancer_names: [elb.load_balancer_name],
    )

    unless asg.instances.empty?
      GhostChef::LoadBalancer.waitfor_all_instances_unavailable(
        elb, asg.instances,
      )
    end

    return true
  end

end
