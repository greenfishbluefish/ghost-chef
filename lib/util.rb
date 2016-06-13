class Util
  def self.descend(obj, keys)
    value = obj
    keys.each { |k| value = value.send(k) }
    return value
  end

  def self.filter(obj, method, args, keys, continue, &filter)
    method = method.to_sym
    continue_check = continue[0].to_sym
    continue_value = continue[1].to_sym

    keys = [keys] if !keys.is_a? Array
    keys = keys.map { |k| k.to_sym }

    rv = obj.send(method, **args)
    items = (self.descend(rv, keys) || []).select(&filter)
    while x = rv.send(continue_check)
      rv = obj.send(method, **args.merge(continue_value => x))
      items.concat (self.descend(rv, keys) || []).select(&filter)
    end

    return items
  end
end
