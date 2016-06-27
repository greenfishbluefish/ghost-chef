##
# These are utility functions used by more than one service.
#
# In general, you will not call these methods directly.
class GhostChef::Util
  ##
  # Not all AWS clients provide a mechanism for filtering results. Some, like
  # the EC2 client, provide great ways of doing so and we use them. Others, like
  # CloudFront or SNS, do not. So, we have to provide a way of doing so.
  #
  # The naive way of doing this would be to load all the return values into RAM,
  # then run the &filter on it. This could be very destructive of memory,
  # depending on how many rows might be returned.
  #
  # Intead, this method applies the filter to the values returned by successive
  # calls to a potentially paginated method and only keeps those values which
  # pass the filter. This can save significant amounts of memory while still
  # performing almost identically.
  #
  # The complexity of this method's signature is because of the various ways
  # the different clients return values. SNS, for example, puts the control
  # values at the top level. CloudFront puts them at the second level.
  def self.filter(obj, methods, args, keys, continue, &filter)
    methods = [methods] if !methods.is_a? Array
    methods = methods.map { |k| k.to_sym }

    continue_check = continue[0].to_sym
    continue_value = continue[1].to_sym

    keys = [keys] if !keys.is_a? Array
    keys = keys.map { |k| k.to_sym }

    rv = obj.send(methods[0], **args)
    rv = descend(rv, methods[1..-1])

    items = (descend(rv, keys) || []).select(&filter)
    while x = rv.send(continue_check)
      rv = obj.send(methods[0], **args.merge(continue_value => x))
      rv = descend(rv, methods[1..-1])

      items.concat (descend(rv, keys) || []).select(&filter)
    end

    return items
  end

  def self.tags_from_hash(tags)
    tags.to_a.map {|v|
      { key: v[0].to_s, value: v[1] }
    }
  end

  private

  def self.descend(obj, keys)
    value = obj
    if keys
      keys.each { |k| value = value.send(k) }
    end
    return value
  end
end
