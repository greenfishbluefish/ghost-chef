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

  ##
  # This method will, given a role, iterate over all the policies attached to
  # that role and return a hash of {name => arn}.
  #
  # It's unlikely you will ever need to call this method directly.
  def self.retrieve_attached_policies(role)
    attached_policies = {}

    # This is a mild abuse of filter() in that we're using it as a map. But, it
    # makes more sense to do this vs. reimplementing filter()'s core logic of
    # iterating over subsequent calls to some method.
    GhostChef::Util.filter(
      @@client,
      :list_attached_role_policies,
      { role_name: role.role_name },
      :attached_policies,
      [ :marker, :marker ]
    ) { |policy|
      attached_policies[policy.policy_name] = policy.policy_arn
      false
    }

    return attached_policies
  end
end
