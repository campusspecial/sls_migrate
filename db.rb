#!/usr/bin/env ruby
# vim:tabstop=2:shiftwidth=2:expandtab

require 'rubygems'
require 'active_record'
require 'yaml'

dbconfig = YAML::load(File.open('database.yml'))
ActiveRecord::Base.establish_connection(dbconfig)

ActiveRecord::Schema.define do
  unless ActiveRecord::Base.connection.tables.include? 'users'
    create_table :users do |table|
      table.column :f_name, :string
      table.column :l_name, :string
      table.column :email, :string
      table.column :short_name, :string
      table.column :sls_id, :integer
      table.column :github_id, :integer
    end
  end

  unless ActiveRecord::Base.conneciton.tables.include? 'tickets'
    create_table :tickets do |table|
      table.column :title, :string
      table.column :body, :text
      table.column :priority, :string
      table.column :is_open, :boolean
      table.column :sls_id, :integer
      table.column :github_id, :integer
      table.column :created, :timestamp
      
      # Foreign Keys
      table.column :owner, :integer
      table.column :project_id, :integer
    end
  end

  unless ActiveRecord::Base.connection.tables.include? 'comments'
    create_table :comments do |table|
      table.column :comment, :text
      table.column :sls_id, :integer
      table.column :github_id, :integer
      table.column :created, :timestamp

      # Foreign Keys
      table.column :owner, :integer
    end
  end

  unless ActiveRecord::Base.connection.tables.include? 'labelings'
    create_table :labelings do |table|
      # many-to-many facilitator
      table.column :label, :integer
      table.column :ticket, :integer
    end
  end
end

class SLSUser
  include DataMapper::Resource
  
  property :id, Serial
  property :f_name, String
  property :l_name, String
  property :email, String
  property :short_name, String
  property :sls_id, Integer, :key => true
  property :github_id, Integer, :key => true

  has n, :tickets, 'SLSTicket'
end

class SLSProject
  include DataMapper::Resource

  property :id, Serial
  property :name, String
  property :sls_id, Integer
  property :github_id, Integer

  has n, :tickets, 'SLSTicket'
  has n, :labels, 'SLSLabel'
end

class SLSLabel
  include DataMapper::Resource

  property :name, String
  property :sls_id, Integer
  property :github_id, Integer
  
  belongs_to :project, 'SLSProject'
  has n, :tickets, :through => :labelings
end

class SLSLabeling
  include DataMapper::Resource

  belongs_to :label, 'SLSLabel'
  belongs_to :ticket, 'SLSTicket'
end

class SLSStatusChange
  include DataMapper::Resource

  property :name, String
  property :is_open, Boolean
  property :created, DateTime, :default => DateTime.now
end

class SLSComment
  include DataMapper::Resource

  property :comment, Text
  property :created, DateTime, :default => DateTime.now
  property :sls_id, Integer
  property :github_id, Integer
end

class SLSTicket
  include DataMapper::Resource

  property :title, String
  property :body, Text
  property :priority, String
  property :is_open, Boolean
  property :sls_id, Integer
  property :github_id, Integer

  belongs_to :owner, 'SLSUser'
  belongs_to :project, 'SLSProject'

  #attr_accessor :project, :assigned_to, :labels, :title, :priority, :status, :sls_id, :comments
end


