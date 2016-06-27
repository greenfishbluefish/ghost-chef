##
# This class manages all interaction with ELB, Amazon's Load Balancer service.
class GhostChef::LoadBalancer
  @@client ||= Aws::ElasticLoadBalancing::Client.new

  ##
  # This method will, given a load balancer name, retrieve that load balancer
  # or return nil.
  #
  # In general, use ensure_elb() instead of this method.
  def self.retrieve_elb(name)
    @@client.describe_load_balancers(
      load_balancer_names: [name],
    ).load_balancer_descriptions.first
  rescue Aws::ElasticLoadBalancing::Errors::LoadBalancerNotFound
    nil
  end

  ##
  # This method will, given a load balancer name, array of listeners, and some
  # options, retrieve that load balancer or create it.
  #
  # Listeners - this is an array of hashes (or a single hash) that each contain:
  #   * (R) protocol: "HTTP", "HTTPS", or "TCP"
  #   * (R) load_balancer_port: <Integer>
  #   * (O) instance_protocol: "HTTP", "HTTPS", or "TCP"
  #   * (R) instance_port: <Integer>
  #   * (O) acm_ssl: The ACM certificate per ensure_certificate()
  # If you specify a secure port (e.g., 443), you must specify acm_ssl.
  #
  # Options:
  #   * security_groups: An array of security groups per ensure_security_group()
  #   * subnets: An array of subnets per ensure_subnet()
  #   * tags: This is a hash of key/value pairs.
  def self.ensure_elb(name, listeners, options={})
    elb = retrieve_elb(name)
    if elb
      # TODO: This needs to update the ELB according to the provided parameters
      # if it already exists

      # create/delete _load_balancer_listeners per listeners

      # add/remove tags per options[:tags]
      # attach/detach _load_balancer_ to/from _subnets per options[:subnets]

      # apply_security_groups(options[:security_groups] || [])
      true
    else
      # TODO: validate the listeners
      # TODO: support :acm_ssl
      listeners = [listeners] unless listeners.kind_of? Array

      params = {
        load_balancer_name: name,
        listeners: listeners,
      }

      params[:subnets] = options[:subnets] if options[:subnets]
      params[:tags] = tags_from_hash(options[:tags]) if options[:tags]

      if options[:security_groups]
        params[:security_groups] = options[:security_groups].map {|e|
          e.group_id
        }
      end

      @@client.create_load_balancer(params)

      elb = retrieve_elb(name)
    end

    return elb
  end

  ##
  # This method will, given a load balancer name and a list of possible
  # instances, block until at least one of the instances in that list are
  # available through the provided load balancer.
  def self.waitfor_any_instance_available(elb, instances)
    @@client.wait_until(
      :any_instance_in_service,
      load_balancer_name: elb.load_balancer_name,
      instances: instances.map {|e| { instance_id: e.instance_id } },
    )
  end

  ##
  # This method will, given a load balancer name and a list of possible
  # instances, block until all of the instances in that list are no longer
  # available through the provided load balancer.
  def self.waitfor_all_instances_unavailable(elb, instances)
    @@client.wait_until(
      :instance_deregistered,
      load_balancer_name: elb.load_balancer_name,
      instances: instances.map {|e| { instance_id: e.instance_id } },
    )
  end
end
