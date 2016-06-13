class GhostChef::Util
  def self.descend(obj, keys)
    value = obj
    if keys
      keys.each { |k| value = value.send(k) }
    end
    return value
  end

  def self.filter(obj, methods, args, keys, continue, &filter)
    methods = [methods] if !methods.is_a? Array
    methods = methods.map { |k| k.to_sym }

    continue_check = continue[0].to_sym
    continue_value = continue[1].to_sym

    keys = [keys] if !keys.is_a? Array
    keys = keys.map { |k| k.to_sym }

    rv = obj.send(methods[0], **args)
    rv = self.descend(rv, methods[1..-1])

    items = (self.descend(rv, keys) || []).select(&filter)
    while x = rv.send(continue_check)
      rv = obj.send(methods[0], **args.merge(continue_value => x))
      rv = self.descend(rv, methods[1..-1])

      items.concat (self.descend(rv, keys) || []).select(&filter)
    end

    return items
  end
end
