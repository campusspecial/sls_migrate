#!/usr/bin/env ruby
# vim: ts=2:tw=2:sw=2:expandtab
# vi: ts=2:tw=2:sw=2:expandtab

class Hash
  def symbolize_keys
    self.inject({}) do |item,(k,v)|
      item[k.to_sym] = (v.is_a?(Hash) ? v.symbolize_keys : v)
      item
    end
  end
end
class String
  def trim
    self.gsub(/^[[:space:]]*([^[:space:]].*)?[[:space:]]*$/,'\1').strip
  end
  def filter_html_crap
    html = self
    until html == html.gsub(/<p>(.*)<br \/><br \/>(.*)<\/p>/, '<p>\1</p><p>\2</p>')
      html = html.gsub(/<p>(.*)<br \/><br \/>(.*)<\/p>/, '<p>\1</p><p>\2</p>')
    end
    html
  end
end
