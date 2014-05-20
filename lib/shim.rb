#!/usr/bin/env ruby
# vim: ts=2:tw=2:sw=2:expandtab
# vi: ts=2:tw=2:sw=2:expandtab

class Hash
  def symbolize_keys
    self.inject({}) do |item,(k,v)|
        if v.is_a? Hash or v.is_a? Array
            item[k.to_sym] = v.symbolize_keys
        else
            item[k.to_sym] = v
        end
        item
    end
  end
end
class Array
  def symbolize_keys
    self.map do |item|
      if item.is_a? Hash or item.is_a? Array
        item = item.symbolize_keys
      end
      item
    end
  end
end


