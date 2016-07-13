##
# This class manages all interaction with RDS, Amazon's Relational Database service.
class GhostChef::Database
  @@client ||= Aws::RDS::Client.new

  def self.retrieve_parameter_group(name)
    @@client.describe_db_parameter_groups(
      db_parameter_group_name: name,
    ).db_parameter_groups.first
  rescue Aws::RDS::Errors::DBParameterGroupNotFoundFault
    nil
  end
  def self.ensure_parameter_group(name, options={})
    param_group = retrieve_parameter_group(name)
    unless param_group
      unless options[:engine] && options[:version]
        abort "Must provide a engine and version"
      end

      params = {
        db_parameter_group_name: name,
        db_parameter_group_family: "#{options[:engine]}#{options[:version]}",
        description: options[:description] || "Parameter group #{name}",
      }
      params[:tags] = tags_from_hash(options[:tags]) if options[:tags]

      param_group = @@client.create_parameter_group(params).db_parameter_group

      # TODO: Wait 5 minutes for parameter group to fully materialize
    end
    param_group
  end

  def self.retrieve_option_group(name)
    @@client.describe_option_groups(
      option_group_name: name,
    ).option_groups_list.first
  rescue Aws::RDS::Errors::OptionGroupNotFoundFault
    nil
  end
  def self.ensure_option_group(name, options={})
    option_group = retrieve_option_group(name)
    unless option_group
      params = {
        option_group_name: name,
        engine_name: options[:engine],
        major_engine_version: options[:version],
        option_group_description: options[:description] || "Option group for #{options[:engine]}#{options[:version]}",
      }
      params[:tags] = tags_from_hash(options[:tags]) if options[:tags]

      option_group = @@client.create_option_group(params).option_group
    end
    option_group
  end

  def self.retrieve_subnet_group(name)
    @@client.describe_db_subnet_groups(
      db_subnet_group_name: name,
    ).db_subnet_groups.first
  rescue Aws::RDS::Errors::DBSubnetGroupNotFoundFault
    nil
  end
  def self.ensure_subnet_group(name, options={})
    subnet_group = retrieve_subnet_group(name)
    unless subnet_group
      unless options[:subnets]
        abort "Must provide :subnets"
      end
      unless options[:subnets].length >= 2
        abort "Must provide at least 2 subnets"
      end

      params = {
        db_subnet_group_name: name,
        db_subnet_group_description: options[:description] || "Subnet group for #{name}",
        subnet_ids: options[:subnets].map {|e| e.subnet_id},
      }
      params[:tags] = tags_from_hash(options[:tags]) if options[:tags]

      subnet_group = @@client.create_db_subnet_group(params).db_subnet_group
    end
    subnet_group
  end

  def self.retrieve_database(name)
    @@client.describe_db_instances(
      db_instance_identifier: name,
    ).db_instances.first
  rescue Aws::RDS::Errors::DBInstanceNotFound
    nil
  end

  def self.ensure_database(name, options={})
    db = retrieve_database(name)
    unless db
      # We are deliberately ignoring:
      # * db_security_groups (EC2-Classic only)
      params = {
        db_instance_identifier: name,
        db_name: options[:db_name] || name,
        multi_az: options[:multi_az] || false,
        publicly_accessible: options[:publicly_accessible] || false,
        allocated_storage: options[:allocated_storage] || 5,
        storage_type: options[:storage_type] || 'standard',
        storage_encrypted: options[:storage_encrypted] || true,
        backup_retention_period: options[:backup_retention_period] || 7,
        copy_tags_to_snapshot: options[:copy_tags_to_snapshot] || true,
      }
      params[:tags] = tags_from_hash(options[:tags]) if options[:tags]

      if options[:vpc_security_groups]
        params[:vpc_security_group_ids] = options[:vpc_security_groups].map do |e|
          e.group_id
        end
      elsif options[:vpc_security_group_ids]
        params[:vpc_security_group_ids] = options[:vpc_security_group_ids]
      end

      if options[:parameter_group]
        params[:db_parameter_group_name] = options[:parameter_group].db_parameter_group_name
      elsif options[:db_parameter_group_name]
        params[:db_parameter_group_name] = options[:db_parameter_group_name]
      end

      if options[:option_group]
        params[:option_group_name] = options[:option_group].option_group_name
      elsif options[:option_group_name]
        params[:option_group_name] = options[:option_group_name]
      end

      if options[:subnet_group]
        params[:db_subnet_group_name] = options[:subnet_group].db_subnet_group_name
      elsif options[:subnet_group_name]
        params[:db_subnet_group_name] = options[:subnet_group_name]
      end

      db = @@client.create_db_instance(params)
    end
    db
  end

  def self.waitfor_database_available(db)
    @@client.wait_until(
      :db_instance_available,
      db_instance_identifier: db.db_instance_identifier,
    )
  end
end
