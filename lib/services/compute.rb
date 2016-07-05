##
# This class manages all interaction with ELB, Amazon's Load Balancer service.
class GhostChef::Compute
  @@client ||= Aws::EC2::Client.new

  def self.waitfor_all_instances_terminated(instances)
    @@client.wait_until(
      :instance_terminated,
      instance_ids: instances.map {|e| e.instance_id },
    )
  end
end
