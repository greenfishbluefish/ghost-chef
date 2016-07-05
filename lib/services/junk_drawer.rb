
# This is a junkdrawer of idempotent AWS functionality. It needs to be organized
# and properly API'ed. This code is very much alpha and will break repeatedly.

Everyone = '0.0.0.0/0'

class GhostChef::Clients
  def self.cloudwatch
    @@cloudwatch ||= Aws::CloudWatch::Client.new
  end

  def self.ec2
    @@ec2 ||= Aws::EC2::Client.new
  end

  def self.rds
    @@rds ||= Aws::RDS::Client.new
  end
end

def tags(override={})
  {
    Name: application,
    application: application,
    environment: environment,
  }.merge(override)
end

def filters_from_hash(tags)
  tags.to_a.map {|v|
    { name: "tag:#{v[0]}", values: [v[1]] }
  }
end

def tags_from_hash(tags)
  tags.to_a.map {|v|
    { key: v[0].to_s, value: v[1] }
  }
end

################################################################################
# EC2

def rules_from_hash(rules)
  rules.map do |e|
    rv = Aws::EC2::Types::IpPermission.new(
      ip_protocol: 'tcp',
      from_port: e[:from_port] || e[:port] || nil,
      to_port: e[:to_port] || e[:from_port] || e[:port] || nil,
      ip_ranges: [],
      user_id_group_pairs: [],
      prefix_list_ids: [],
    )
    if e[:source]
      rv.ip_ranges.push(
        Aws::EC2::Types::IpRange.new(
          cidr_ip: e[:source],
        ),
      )
    elsif e[:group]
      rv.user_id_group_pairs.push(
        Aws::EC2::Types::UserIdGroupPair.new(
          group_id: e[:group],
        ),
      )
    end

    rv
  end
end

def ensure_security_group_rules(group, rules)
  {
    ingress: 'ip_permissions',
    egress: 'ip_permissions_egress',
  }.each do |config_type, aws_type|
    aws_rules = group[aws_type]
    config_rules = rules_from_hash(rules[config_type] || [])

    to_revoke = []
    aws_rules.each do |rule|
      to_revoke.push(rule) unless config_rules.include?(rule)
    end
    unless to_revoke.empty?
      GhostChef::Clients.ec2.send("revoke_security_group_#{config_type}".to_sym, {
        group_id: group.group_id,
        ip_permissions: to_revoke.map {|e|
          x = e.to_h
          x[:user_id_group_pairs] = nil if x[:user_id_group_pairs] && x[:user_id_group_pairs].empty?
          x[:prefix_list_ids] = nil if x[:prefix_list_ids] && x[:prefix_list_ids].empty?
          x[:ip_ranges] = nil if x[:ip_ranges] && x[:ip_ranges].empty?
          x
        },
      })
    end

    to_authorize = []
    config_rules.each do |rule|
      to_authorize.push(rule) unless aws_rules.include?(rule)
    end
    unless to_authorize.empty?
      GhostChef::Clients.ec2.send("authorize_security_group_#{config_type}".to_sym, {
        group_id: group.group_id,
        ip_permissions: to_authorize.map {|e|
          x = e.to_h
          x[:user_id_group_pairs] = nil if x[:user_id_group_pairs] && x[:user_id_group_pairs].empty?
          x[:prefix_list_ids] = nil if x[:prefix_list_ids] && x[:prefix_list_ids].empty?
          x[:ip_ranges] = nil if x[:ip_ranges] && x[:ip_ranges].empty?
          x
        },
      })
    end
  end
end

def retrieve_security_group(vpc, name)
  GhostChef::Clients.ec2.describe_security_groups(
    filters: [
      { name: 'group-name', values: [name] },
      { name: 'vpc-id', values: [vpc.vpc_id] },
    ],
  ).security_groups[0]
end
def ensure_security_group(vpc, name, description, tags={})
  secgrp = retrieve_security_group(vpc, name)

  unless secgrp
    group_id = GhostChef::Clients.ec2.create_security_group(
      group_name: name,
      description: description,
      vpc_id: vpc.vpc_id,
    ).group_id

    unless tags.empty?
      GhostChef::Clients.ec2.create_tags(
        resources: [group_id],
        tags: tags_from_hash(tags),
      )
    end

    secgrp = retrieve_security_group(vpc, name)
  end

  return secgrp
end

def retrieve_vpc(tags)
  GhostChef::Clients.ec2.describe_vpcs(
    filters: filters_from_hash(tags),
  ).vpcs[0]
end
def ensure_vpc(cidr_block, tags)
  # Do we want to add a filter on the cidr_block as well?
  vpc = retrieve_vpc(tags)
  unless vpc
    vpc = GhostChef::Clients.ec2.create_vpc(
      cidr_block: cidr_block,
      instance_tenancy: 'default',
    ).vpc

    GhostChef::Clients.ec2.create_tags(
      resources: [vpc.vpc_id],
      tags: tags_from_hash(tags),
    )

    vpc = retrieve_vpc(tags)
  end

  return vpc
end

def retrieve_subnet(vpc, zone)
  subnet = GhostChef::Clients.ec2.describe_subnets(
    filters: [
      { name: 'vpc-id', values: [vpc.vpc_id] },
      { name: 'availability-zone', values: [zone] },
    ],
  ).subnets[0]
end
def ensure_subnet(vpc, zone, cidr_block, tags={})
  subnet = retrieve_subnet(vpc, zone)

  unless subnet
    subnet = GhostChef::Clients.ec2.create_subnet(
      vpc_id: vpc.vpc_id,
      cidr_block: cidr_block,
      availability_zone: zone,
    ).subnet

    unless tags.empty?
      GhostChef::Clients.ec2.create_tags(
        resources: [subnet.subnet_id],
        tags: tags_from_hash(tags),
      )
    end

    subnet = retrieve_subnet(vpc, zone)
  end

  return subnet
end

def retrieve_internet_gateway(tags)
  GhostChef::Clients.ec2.describe_internet_gateways(
    filters: filters_from_hash(tags),
  ).internet_gateways[0]
end
def ensure_internet_gateway(tags)
  inet_gway = retrieve_internet_gateway(tags)

  unless inet_gway
    inet_gway = GhostChef::Clients.ec2.create_internet_gateway(
    ).internet_gateway

    GhostChef::Clients.ec2.create_tags(
      resources: [inet_gway.internet_gateway_id],
      tags: tags_from_hash(tags),
    )

    inet_gway = retrieve_internet_gateway(tags)
  end

  return inet_gway
end

def ensure_vpc_attached_gateway(vpc, inet_gway)
  vpc_is_attached = false
  inet_gway.attachments.each do |attachment|
    if attachment.vpc_id == vpc.vpc_id
      # TODO: Handle the states 'attaching', 'detaching', 'detached'
      vpc_is_attached = true
    end
  end
  unless vpc_is_attached
    GhostChef::Clients.ec2.attach_internet_gateway(
      internet_gateway_id: inet_gway.internet_gateway_id,
      vpc_id: vpc.vpc_id,
    )
  end
end

def retrieve_route_table(vpc)
  GhostChef::Clients.ec2.describe_route_tables(
    filters: [
      { name: 'vpc-id', values: [ vpc.vpc_id ] },
    ],
  ).route_tables[0]
end
def ensure_vpc_routes_to_gateway(vpc, inet_gway)
  table = retrieve_route_table(vpc)

  gway_is_attached = false
  table.routes.each do |route|
    if route.gateway_id == inet_gway.internet_gateway_id
      gway_is_attached = true
    end
  end

  unless gway_is_attached
    GhostChef::Clients.ec2.create_route(
      route_table_id: table.route_table_id,
      destination_cidr_block: '0.0.0.0/0',
      gateway_id: inet_gway.internet_gateway_id,
    )
  end
end

def ensure_instances_are_launched(instances)
  unless instances.empty?
    GhostChef::Clients.ec2.wait_until(
      :instance_running,
      instance_ids: instances.map {|e| e.instance_id },
    )
  end
end

def retrieve_ami(id)
  GhostChef::Clients.ec2.describe_images(
    image_ids: [id],
  ).images[0]
end

def retrieve_latest_ami(tags)
  GhostChef::Clients.ec2.describe_images(
    filters: filters_from_hash(tags),
  ).images.sort_by {|e| e.creation_date}.last
end

def destroy_ami(ami)
  puts "  De-registering image"
  GhostChef::Clients.ec2.deregister_image(
    image_id: ami.image_id,
  )

  ami.block_device_mappings.each do |snapshot|
    if snapshot.ebs
      puts "  Destroying snapshot"
      GhostChef::Clients.ec2.delete_snapshot(
        snapshot_id: snapshot.ebs.snapshot_id,
      )
    end
  end
end

################################################################################
# CloudWatch, EC2, RDS, ELB

class CloudWatch
  def self.metrics
    {
      # EC2/RDS metrics
      cpu: 'CPUUtilization',                        # min, max
      memory: 'FreeableMemory',                     # min, max

      # EC2-only metrics
      status_fail: 'StatusCheckFailed',             # min

      # ELB metrics
      healthy_hosts: 'HealthyHostCount',            # min, max
      unhealthy_hosts: 'UnHealthyHostCount',        # min, max
      requests: 'RequestCount',                     # sum
      backend_latency: 'Latency',                   # average, max
      queued_requests: 'SurgeQueueLength',          # max (limited to 1024)
      dropped_requests: 'SpilloverCount',           # sum
      backend_errors: 'BackendConnectionErrors',    # sum
      elb_4xx: 'HTTPCode_ELB_4XX',                  # sum
      elb_5xx: 'HTTPCode_ELB_5XX',                  # sum
      backend_2xx: 'HTTPCode_Backend_2XX',          # sum
      backend_3xx: 'HTTPCode_Backend_3XX',          # sum
      backend_4xx: 'HTTPCode_Backend_4XX',          # sum
      backend_5xx: 'HTTPCode_Backend_5XX',          # sum
    }
  end

  def self.comparisons
    {
      '>'  => 'GreaterThanThreshold',
      '>=' => 'GreaterThanOrEqualToThreshold',
      '<'  => 'LessThanThreshold',
      '<=' => 'LessThanOrEqualToThreshold',
    }
  end

  def self.units
    {
      mb: 1024*1024,
      MB: 1024*1024,
    }
  end

  def self.statistics
    {
      average: 'Average',
      sample: 'SampleCount',
      minimum: 'Minimum',
      maximum: 'Maximum',
      total: 'Sum',
    }
  end
end

def ensure_alarm(params)
  # TODO: make sure type and metric are properly lined up.

  opts = {
    statistic: :average,

    # FIXME: Confirm this is a proper amount of seconds
    period: 300,

    # FIXME: Confirm this is 1-5 inclusive
    periods: 2,
  }.merge(params)

  # TODO: Verify we received the following:
  # :name
  # :type
  # :metric
  # :threshold
  # :action

  # Convert these client calls to the methods provided above.
  case opts[:type]
  when :ec2
    dimension = {
      name: 'InstanceId',
    }
    opts[:namespace] = 'AWS/EC2'

    # Verify the instance actually exists and find its instance_id.
    begin
      reservations = GhostChef::Clients.ec2.describe_instances(
        filters: [
          { name: 'tag:Name', values: [ opts[:name] ] },
        ],
      ).reservations
      if reservations.length > 0
        dimension[:value] = reservations[0].instances[0].instance_id
      else
        abort "Cannot find EC2 instance #{opts[:name]}"
      end
    rescue Aws::EC2::Errors::ServiceError => e
      puts "#{e.class}: #{e}"
      abort "Problem finding EC2 instance #{opts[:name]}"
    end
  when :elb
    # Could also be AvailablilityZone
    dimension = {
      name: 'LoadBalancerName',
      value: opts[:name],
    }
    opts[:namespace] = 'AWS/ELB'

    # Verify the elb actually exists and find its name
    elb = GhostChef::LoadBalancer.retrieve_elb(opts[:name])
    abort "Cannot find ELB #{opts[:name]}" unless elb
  when :rds
    dimension = {
      name: 'DBInstanceIdentifier',
      value: opts[:name],
    }
    opts[:namespace] = 'AWS/RDS'

    # Verify the instance actually exists.
    begin
      GhostChef::Clients.rds.describe_db_instances(
        db_instance_identifier: opts[:name],
      )
    rescue Aws::RDS::Errors::DBInstanceNotFound
      abort "RDS instance #{opts[:name]} doesn't exist"
    end
  else
    abort "Cannot handle #{opts[:type]} for dimension"
  end

  # Default the comparison operator by whatever the metric is
  if CloudWatch.metrics.has_key? opts[:metric]
    opts[:comparison] ||=
      case opts[:metric]
      when :cpu, :status_fail, :unhealthy_hosts, :backend_errors
        '>='
      when :memory, :healthy_hosts
        '<='
      end
  else
    abort "Cannot handle metric '#{opts[:metric]}'"
  end

  unless CloudWatch.statistics.has_key? opts[:statistic]
    abort "Cannot handle statistic type #{opts[:statistic]}"
  end

  # Do this last so everything can have a chance to be set.
  name = [
    opts[:name],
    opts[:type].downcase,
    opts[:metric].downcase,
    case opts[:comparison]
    when '>=', '>'
      'high'
    when '<=', '<'
      'low'
    else
      'other'
    end,
  ].join('-')

  alarm_params = {
    alarm_name: name,
    #alarm_description: '',
    actions_enabled: true,
    ok_actions: [ opts[:action] ],
    alarm_actions: [ opts[:action] ],
    insufficient_data_actions: [ opts[:action] ],
    metric_name: CloudWatch.metrics[opts[:metric]],
    namespace: opts[:namespace],
    statistic: CloudWatch.statistics[opts[:statistic]],
    dimensions: [ dimension ],
    period: opts[:period],
    # Unit appears to be ignored in some cases. Ignore it for now.
    #unit: nil,
    evaluation_periods: opts[:periods],
    threshold: opts[:threshold],
    comparison_operator: CloudWatch.comparisons[opts[:comparison]],
  }

  # Unit appears to be ignored in some cases. Ignore it for now.
  if opts.has_key? :unit
    if CloudWatch.units.has_key? opts[:unit]
      # TODO: to_i may not be appropriate. Do we want to_f instead?
      alarm_params[:threshold] = alarm_params[:threshold].to_i * CloudWatch.units[opts[:unit]]
    else
      abort "Cannot handle unit #{opts[:unit]}"
    end
  end

  # TODO: Add a check to see if the alarm already exists
  puts "Updating the #{name} alarm"
  GhostChef::Clients.cloudwatch.put_metric_alarm(alarm_params)

  # Verify the alarm goes into OK.
end
