##
# This class manages all interaction with IAM, Amazon's Authn/Authz service.
class GhostChef::IAM
  @@client ||= Aws::IAM::Client.new

  ##
  # This method will, given a role name, retrieve that role or return nil.
  #
  # In general, use ensure_role() instead of this method.
  def self.retrieve_role(name)
    @@client.get_role(role_name: name).role
  rescue Aws::IAM::Errors::NoSuchEntity
    nil
  end

=begin
  def self.retrieve_attached_policies(role)
    attached_policies = {}
    resp = @@client.list_attached_role_policies(
      role_name: role.role_name,
    )
    resp.attached_policies.each do |policy|
      attached_policies[policy.policy_name] = policy.policy_arn
    end

    while resp.is_truncated
      resp = @@client.list_attached_role_policies(
        role_name: role.role_name,
        marker: resp.marker,
      )
      resp.attached_policies.each do |policy|
        attached_policies[policy.policy_name] = policy.policy_arn
      end
    end

    return attached_policies
  end
=end
end
