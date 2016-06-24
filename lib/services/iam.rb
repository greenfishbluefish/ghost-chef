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

  def self.role_policy(options={})
    JSON.generate({
      "Version" => "2012-10-17",
      "Statement" => {
        "Effect" => "Allow",
        "Principal" => {"Service" => "ec2.amazonaws.com"},
        "Action" => "sts:AssumeRole",
      },
    })
  end

  def self.ensure_role(name, options={})
    assume_role_policy = role_policy(options)

    role = retrieve_role(name)
    if role
      @@client.update_assume_role_policy(
        role_name: role.role_name,
        policy_document: assume_role_policy,
      )
    else
      role = @@client.create_role(
        role_name: name,
        assume_role_policy_document: assume_role_policy,
      ).role
    end

    ensure_attached_policies(role, options[:policies]) if options[:policies]

    return role
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

  def self.ensure_attached_policies(role, policies={})
    attached_policies = retrieve_attached_policies(role)

    options[:policies].each do |policy_name|
      # Ignore the roles that are there and should be there
      if attached_policies[policy_name]
        attached_policies.delete(policy_name)
        next
      end

      # Attach the roles that should be there
      @@client.attach_role_policy(
        role_name: role.role_name,
        policy_arn: "arn:aws:iam::aws:policy/#{policy_name}",
      )
    end

    # Remove the roles that should no longer be there
    attached_policies.each do |name, arn|
      @@client.detach_role_policy(
        role_name: role.role_name,
        policy_arn: arn,
      )
    end

    return true
  end

  ##
  # This method will, given a instance profile name, retrieve that instance
  # profile or return nil.
  #
  # In general, use ensure_instance_profile() instead of this method.
  def self.retrieve_instance_profile(name)
    @@client.get_instance_profile(instance_profile_name: name).instance_profile
  rescue Aws::IAM::Errors::NoSuchEntity
    nil
  end

  def self.ensure_instance_profile(name, options)
    instance_profile = retrieve_instance_profile(name)
    unless instance_profile
      instance_profile = @@client.create_instance_profile(
        instance_profile_name: name,
      ).instance_profile
    end

    attached_roles = instance_profile.roles.map{|e| [e.role_name, true]}.to_h
    options[:roles].each do |role|
      if attached_roles[role.role_name]
        attached_roles.delete(role.role_name)
        next
      end

      @@client.add_role_to_instance_profile(
        instance_profile_name: instance_profile.instance_profile_name,
        role_name: role.role_name,
      )
    end

    attached_roles.each do |role_name, _|
      @@client.remove_role_from_instance_profile(
        instance_profile_name: instance_profile.instance_profile_name,
        role_name: role_name,
      )
    end
  end
end
