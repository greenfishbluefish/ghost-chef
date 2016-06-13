class Util
  def self.filter(obj, method, args, keys, continue, &filter)
    method = method.to_sym
    continue_check = continue[0].to_sym
    continue_value = continue[1].to_sym

    rv = obj.send(method, **args)
    items = (rv.send(keys.to_sym) || []).select(&filter)
    while x = rv.send(continue_check)
      rv = obj.send(method, **args.merge(continue_value => x))
      items.concat (rv.send(keys.to_sym) || []).select(&filter)
    end

    return items
  end
end
