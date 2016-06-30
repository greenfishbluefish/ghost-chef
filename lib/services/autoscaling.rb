##
# This class manages all interaction with ELB, Amazon's Load Balancer service.
class GhostChef::AutoScaling
  @@client ||= Aws::AutoScaling::Client.new

  def self.retrieve_launch_configuration(name)
    @@client.describe_launch_configurations(
      launch_configuration_names: [name]
    ).launch_configurations[0]
  end

  def self.ensure_launch_configuration(name, options={})
    configuration = retrieve_launch_configuration(name)
    if configuration
      # TODO: Update the launch_configuration here accordingly.
      true
    else
      params = {
        launch_configuration_name: name,
      }

      params[:image_id] = options[:image_id] if options[:image_id]
      params[:security_groups] = options[:security_groups] if options[:security_groups]
      params[:instance_type] = options[:instance_type] if options[:instance_type]
      params[:key_name] = options[:key_name] if options[:key_name]

      @@client.create_launch_configuration(params)

      configuration = retrieve_launch_configuration(name)
    end

    return configuration
  end

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
