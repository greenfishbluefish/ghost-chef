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
  # This method will provide an assume role policy document, required by
  # ensure_role().
  #
  # It's unlikely you will ever need to call this method directly.
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

  ##
  # This method will, given a role name and some options, retrieve that role or
  # create it.
  #
  # Options:
  #   * policies: If a list of policy names are provided, then this will call
  #     ensure_attached_policies(). Please see that method for more details.
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

  ##
  # This method will, given a role and an array of desired policy names, iterate
  # over all the policies attached to that role and ensure that the policies are
  # exactly what you have specified.
  #
  # This method will add or remove policies as required. The correlation is by
  # policy name and is case-sensitive.
  #
  # If you provide no policy names, this **WILL REMOVE ALL ATTACHED POLICIES**.
  # You have been warned.
  #
  # It's unlikely you will ever need to call this method directly. It is called
  # by ensure_role().
  def self.ensure_attached_policies(role, policies=[])
    attached_policies = retrieve_attached_policies(role)

    policies.each do |policy_name|
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

  ##
  # This method will, given an instance profile name and some options, retrieve
  # that instance profile or create it.
  #
  # Options:
  #   * roles: If a set of roles/role names are given, ensure_attached_roles()
  #     will be called for you. Please see that method for more details.
  def self.ensure_instance_profile(name, options={})
    profile = retrieve_instance_profile(name)
    unless profile
      profile = @@client.create_instance_profile(
        instance_profile_name: name,
      ).instance_profile
    end

    ensure_attached_roles(profile, options[:roles]) if options[:roles]

    return profile
  end

  ##
  # This method will, given an instance profile, iterate over all the roles
  # attached to that instance profile and return a hash of {name => true}.
  #
  # It's unlikely you will ever need to call this method directly. It is called
  # by ensure_instance_profile().
  def self.retrieve_attached_roles(profile)
    profile.roles.map{|e| [e.role_name, true]}.to_h
  end

  ##
  # This method will, given an instance profile and an array of desired roles
  # (or role names), iterate over all the roles attached to that instance
  # profile and ensure that the roles are exactly what you have specified.
  #
  # This method will add or remove roles as required. The correlation is by
  # role name and is case-sensitive.
  #
  # If you provide no roles, this **WILL REMOVE ALL ATTACHED ROLES**.
  # You have been warned.
  #
  # It's unlikely you will ever need to call this method directly. It is called
  # by ensure_instance_profile().
  def self.ensure_attached_roles(profile, roles=[])
    attached_roles = retrieve_attached_roles(profile)

    roles.each do |name|
      # Normalize to the role name
      name = role.role_name unless name.is_a? String

      if attached_roles[name]
        attached_roles.delete(name)
        next
      end

      @@client.add_role_to_instance_profile(
        instance_profile_name: profile.instance_profile_name,
        role_name: name,
      )
    end

    attached_roles.each do |name, _|
      @@client.remove_role_from_instance_profile(
        instance_profile_name: profile.instance_profile_name,
        role_name: name,
      )
    end

    return true
  end
end
