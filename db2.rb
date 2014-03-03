#!/usr/bin/env ruby
# vim: ts=2:tw=2:sw=2:expandtab
# vi: ts=2:tw=2:sw=2:expandtab

require 'rubygems'
require 'sqlite3'
require 'active_record'
require 'yaml'

module SLS
  dbconfig = YAML::load(File.open('database.yml'))
  ActiveRecord::Base.establish_connection(dbconfig)

  def self.import_ticket_nums(project_name, filename)
    proj = SLS::Project.where(:name => project_name).first
    File.readlines(filename).each do |line|
      num = line.chomp.scan(/^(\d+),/)
      unless num.empty?
        SLS::Ticket.find_or_create_by(:sls_id => num[0][0].to_i, :project_id => proj.id)
      end
    end
  end
  
  ActiveRecord::Schema.define do
    unless ActiveRecord::Base.connection.tables.include? 'tickets'
      create_table :tickets do |table|
        table.string :title
        table.text :body
        table.string :priority
        table.boolean :is_open
        table.integer :sls_id
        table.integer :github_id
        table.datetime :created

        # Foreign keys
        table.integer :project_id # project
        table.integer :owner_id # user
      end
    end

    unless ActiveRecord::Base.connection.tables.include? 'users'
      create_table :users  do |table|
        table.string :f_name
        table.string :l_name
        table.string :email
        table.string :short_name
        table.integer :sls_id
        table.integer :github_id
      end
    end

    unless ActiveRecord::Base.connection.tables.include? 'projects'
      create_table :projects do |table|
        table.string :name
        table.integer :sls_id
        table.integer :github_id
      end
    end
  end


  class Ticket < ActiveRecord::Base
    belongs_to :project
    belongs_to :owner, :class_name => 'SLS::User'
    has_many :workers, :class_name => 'SLS::User', :through => :ticket_assignments
  end

  class Project < ActiveRecord::Base
    has_many :tickets
  end

  class User < ActiveRecord::Base
    has_many :creations, :class_name => 'SLS::Ticket'
    has_many :assignments, :class_name => 'SLS::Ticket', :through => :ticket_assignments
  end
end
