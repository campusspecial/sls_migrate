#!/usr/bin/env ruby
# vim: ts=2:tw=2:sw=2:expandtab

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

  unless ActiveRecord::Base.connection.tables.include? 'projects'
    create_table :projects do |table|
      table.column :name, :string
      table.column :sls_id, :integer
      table.column :github_id, :integer
    end
  end

  unless ActiveRecord::Base.connection.tables.include? 'projectassignments'
    create_table :projectassignments do |table|
      # many-to-many facilitator
      table.column :project_id, :integer
      table.column :user_id, :integer
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

  unless ActiveRecord::Base.connection.tables.include? 'ticketassignments'
    create_table :ticketassignments do |table|
      # many-to-many facilitator
      table.column :user, :integer
      table.column :ticket, :integer
    end
  end

  unless ActiveRecord::Base.connection.tables.include? 'labels'
    create_table :labels do |table|
      table.column :name, :string
      
      # Foreign keys
      table.column :project_id, :integer
    end
  end

  unless ActiveRecord::Base.connection.tables.include? 'labelings'
    create_table :labelings do |table|
      # many-to-many facilitator
      table.column :label, :integer
      table.column :ticket, :integer
    end
  end

  unless ActiveRecord::Base.connection.tables.include? 'ticketevents'
    create_table :ticketevents do |table|
      table.column :created, :timestamp
      table.column :table, :string
      table.column :table_id, :integer

      # Foreign keys
      table.column :ticket_id, :integer
    end
  end

  unless ActiveRecord::Base.connection.tables.include? 'comments'
    create_table :comments do |table|
      table.column :comment, :text
      table.column :sls_id, :integer
      table.column :github_id, :integer
      table.column :created, :timestamp

      # Foreign keys
      table.column :owner, :integer # user account
      table.column :ticketevent_id, :integer
    end
  end

  unless ActiveRecord::Base.connection.tables.include? 'statuschanges'
    create_table :statuschanges do |table|
      table.column :name, :string
      table.column :is_open, :boolean
      table.column :created, :timestamp

      # Foreign keys
      table.column :ticketevent_id, :integer
    end
  end
end

class User < ActiveRecord::Base
  has_many :creations, :class_name => 'Ticket'
  has_many :assignments, :class_name => 'Ticket', :through => :ticket_assignments
  has_many :projects, :through => :project_assignments
  has_many :comments
  has_many :activities

  def recent_activities(limit)
    activities.order('created_at DESC').limit(limit)
  end
end

class Project < ActiveRecord::Base
  has_many :users, :through => :project_assigments
  has_many :activities, :through => :tickets
end

class Ticket < ActiveRecord::Base
  belongs_to :project
  belongs_to :creator, :class_name => 'User'

  has_many :workers, :class_name => 'User', :through => :ticket_assignments

  has_many :activities

  has_many :comments
  has_many :status_changes
  has_and_belongs_to_many :labels

  def recent_activities(limit)
    activities.order('created_at DESC').limit(limit)
  end

  def status
    status_changes.last
  end
end

class Activity < ActiveRecord::Base
  belongs_to :subject, :polymorphic => true
  belongs_to :user
end

class Label < ActiveRecord::Base
  belongs_to :project
  has_and_belongs_to_many :tickets
end

class Comment < ActiveRecord::Base
  belongs_to :ticket
  belongs_to :user

  after_create :create_activities

  def boss
    ticket.owner
  end

  private

  def create_activities
    [boss, user].uniq.each do |person|
    #[boss].push(user).uniq.each do |person|
      Activity.create(
        subject: self,
        name: 'comment_posted',
        ticket: ticket,
        user: person
      )
    end
  end
end

class StatusChange < ActiveRecord::Base
  belongs_to :ticket
  belongs_to :user

  after_create :create_activities

  def is_open?
    # switch statement determining open/closed status based on string name
    false
  end

  private

  def create_activities
    Activity.create(
      subject: self,
      name: 'status_changed',
      ticket: ticket,
      user: user
    )
  end
end

class ProjectAssignment < ActiveRecord::Base
  belongs_to :project
  belongs_to :user
end

class TicketAssignment < ActiveRecord::Base
  belongs_to :ticket
  belongs_to :user
end


# ==================================================


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
