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

  def self.destroy_launch_configuration(name)
  end

  def self.retrieve_auto_scaling_groups(options)
    # Name is unique, so return just the one item
    if options.has_key? :name
      return @@client.describe_auto_scaling_groups(
        auto_scaling_group_names: [options[:name]]
      ).auto_scaling_groups[0]
    end

    # This performs an AND upon the options provided.
    return GhostChef::Util.filter(
      @@client,
      :describe_auto_scaling_groups,
      {max_records: 100},
      :auto_scaling_groups,
      [:next_token, :next_token],
    ) do |asg|
      keep = true
      options.each do |type, value|
        v = asg.send(type)
        # There are no tests for handling array values.
        #if v.is_a? Array
        #  keep = keep && v.include?(value)
        #else
          keep = keep && v == value
        #end
      end
      keep
    end
      # XXX: Convert this to use filter() above.
      # describe_auto_scaling_groups() does not provide a filtering mechanism, so
      # provide our own.
      #resp = @@client.describe_auto_scaling_groups(max_records: 100)
      #groups = resp.auto_scaling_groups
      #while resp.next_token
      #  resp = @@client.describe_auto_scaling_groups(
      #    max_records: 100,
      #    next_token: resp.next_token,
      #  )
      #  groups.concat resp.auto_scaling_groups
      #end
      #
      #options.each do |type, value|
      #  groups.select! {|e|
      #    v = e.send(type)
      #    if v.is_a? Array
      #      v.include? value
      #    else
      #      v == value
      #    end
      #  }
      #end

      #return groups
    #end
  end

  def self.ensure_auto_scaling_group(name, options={})
    auto_scaling_group = retrieve_auto_scaling_groups(name: name)

    if auto_scaling_group
      # TODO: Update the auto-scaling group per the options provided.
      true
    else
      # TODO: Validate the options provided.
      params = {
        auto_scaling_group_name: name,
        min_size: options[:min_size] || 1, # Int
        max_size: options[:max_size] || 1, # Int
      }

      # TODO: Validate either a launch-config or instance_id is provided.
      [
        :availability_zones, # Array of Zones
        :desired_capacity, # Int
        :launch_configuration_name, # launch_config name (provide by obj?)
        :load_balancer_names, # Array of LB names
        :vpc_zone_identifier, # vpc identifier (provide by obj?)
      ].each do |opt|
        params[opt] = options[opt] if options[opt]
      end

      params[:tags] = tags_from_hash(options[:tags]) if options[:tags]

      @@client.create_auto_scaling_group(params)

      auto_scaling_group = retrieve_auto_scaling_groups(name: name)
    end

    return auto_scaling_group
  end

  def self.destroy_auto_scaling_group(asg)
    # Normalize what we receive.
    asg = retrieve_auto_scaling_groups(name: asg) if asg.is_a? String

    # Ensure that all instances are terminated and no longer spawns instances.
    # We cannot destroy the ASG until this is true.
    @@client.update_auto_scaling_group(
      auto_scaling_group_name: asg.auto_scaling_group_name,
      min_size: 0,
      max_size: 0,
      desired_capacity: 0,
    )

    unless asg.instances.empty?
      GhostChef::Compute.waitfor_all_instances_terminated(asg.instances)
    end

    @@client.delete_auto_scaling_group(
      auto_scaling_group_name: asg.auto_scaling_group_name,
      force_delete: true,
    )

    return true

    #launch_config_name = asg.launch_configuration_name
    #image_id = retrieve_launch_configuration(launch_config_name).image_id

    # We have to delete the launch configuration after the ASG
    #@@client.delete_launch_configuration(
    #  launch_configuration_name: launch_config_name,
    #)

    # We have to delete the AMI after the launch configuration
    #destroy_ami(retrieve_ami(image_id))
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
