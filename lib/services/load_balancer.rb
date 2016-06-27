##
# This class manages all interaction with ELB, Amazon's Load Balancer service.
class GhostChef::LoadBalancer
  @@client ||= Aws::ElasticLoadBalancing::Client.new

  def self.retrieve_elb(name)
    @@client.describe_load_balancers(
      load_balancer_names: [name],
    ).load_balancer_descriptions.first
  end
end
