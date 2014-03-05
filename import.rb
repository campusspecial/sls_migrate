#!/usr/bin/env ruby
# vim: ts=2:tw=2:sw=2:expandtab
# vi: ts=2:tw=2:sw=2:expandtab
require 'yaml'
require './db'
require './crawler'

class Hash
  def symbolize_keys
    self.inject({}) {|item,(k,v)| item[k.to_sym] = v; item}
  end
end

sls = YAML::load(File.open('springloops.yml')).symbolize_keys

SLS::cleanup_db if sls[:cleanup_db]

$proj = SLS::Project.where(:sls_id => sls[:project_id], :name => sls[:project_name]).first_or_create
$bot = SLS::Crawler.new(
  :username => sls[:username],
  :password => sls[:password],
  :organization => sls[:organization]
)
SLS::import_ticket_nums $proj.name, sls[:project_csv]

