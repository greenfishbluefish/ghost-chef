##
# This class manages all interaction with RDS, Amazon's Relational Database service.
class GhostChef::Database
  @@client ||= Aws::RDS::Client.new

  def self.retrieve_parameter_group(name)
    @@client.describe_db_parameter_groups(
      db_parameter_group_name: name,
    ).db_parameter_groups.first
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
      params = {
        db_instance_identifier: name,
        db_name: options[:db_name] || name,
        multi_az: options[:multi_az] || false,
        publicly_accessible: options[:publicly_accessible] || false,
      }
      params[:tags] = tags_from_hash(options[:tags]) if options[:tags]

      db = @@client.create_db_instance(params)
    end
    db
  end
end
