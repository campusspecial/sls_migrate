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
        SLS::Ticket.find_or_create_by(
          :sls_id => num[0][0].to_i,
          :project_id => proj.id
        )
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

    unless ActiveRecord::Base.connection.tables.include? 'assignments'
      create_table :assignments do |table|
        table.integer :subject_id, :null => false
        table.string :subject_type, :null => false
        table.integer :assignable_id, :null => false
        table.string :assignable_type, :null => false
      end
    end

    unless ActiveRecord::Base.connection.tables.include? 'activities'
      create_table :activities do |table|
        table.integer :subject_id, :null => false
        table.string :subject_type, :null => false
        table.integer :activity_id, :null => false
        table.string :activity_type, :null => false
      end
    end

    unless ActiveRecord::Base.connection.tables.include? 'comments'
      create_table :comments do |table|
        table.text :body, :null => false
        table.integer :author_id, :null => false
        table.datetime :created
        table.integer :ticket_id, :null => false
        table.integer :sls_id
      end
    end

    unless ActiveRecord::Base.connection.tables.include? 'status_changes'
      create_table :status_changes do |table|
        table.boolean :open, :default => true, :null => false
        table.string :status
        table.integer :ticket_id, :null => false
        table.integer :author, :null => false
      end
    end
  end


  class Ticket < ActiveRecord::Base
    belongs_to :project, :class_name => 'SLS::Project'
    belongs_to :owner, :class_name => 'SLS::User'
    has_many :assignments, :class_name => 'SLS::Assignment', :as => :assignable
    has_many :workers, :class_name => 'SLS::User', :through => :assignments,
      :as => :subject, :source => :subject, :source_type => 'SLS::User'
    has_many :status_changes, :class_name => 'SLS::StatusChange'
    has_many :activities, :class_name => 'SLS::Activity', :as => :activity
    has_many :comments, :class_name => 'SLS::Comment', :through => :activities,
      :as => :subject, :source => :subject, :source_type => 'SLS::Comment'

    def add_worker(user)
      self.assign user if user.is_a? SLS::User
    end

    def add_label(label)
      self.assign label if label.is_a? SLS::Label
    end

    def add_comment(body, author, sls_id=nil, created=DateTime.now)
      SLS::Comment.create(
        :body => body,
        :author => author,
        :ticket => self,
        :sls_id => sls_id,
        :created => created
      ) if author.is_a?(SLS::User) && created.is_a?(DateTime)
    end

    def assign(tag)
      SLS::Assignment.create(:subject => tag, :assignable => self)
      self.reload
    end
  end

  class Project < ActiveRecord::Base
    has_many :tickets, :class_name => 'SLS::Ticket'
  end

  class User < ActiveRecord::Base
    has_many :creations, :class_name => 'SLS::Ticket'
    has_many :assignments, :class_name => 'SLS::Assignment', :as => :subject
    has_many :tasks, :source => :assignable, :source_type => 'SLS::Ticket',
      :class_name => 'SLS::Ticket', :through => :assignments
    has_many :comments, :class_name => 'SLS::Comment', :foreign_key => :author_id
  end

  class Comment < ActiveRecord::Base
    belongs_to :ticket, :class_name => 'SLS::Ticket'
    belongs_to :author, :class_name => 'SLS::User'
    after_create :create_activities

    private

    def create_activities
      SLS::Activity.create(
        :activity => self,
        :subject => self.ticket
      )
    end
  end

  class StatusChange < ActiveRecord::Base
    belongs_to :ticket, :class_name => 'SLS::Ticket'
    belongs_to :author, :class_name => 'SLS::User'
    after_create :create_activities

    private

    def create_activities
      SLS::Activity.create(
        :activity => self,
        :subject => self.ticket
      )
    end
  end

  class Label < ActiveRecord::Base
    belongs_to :project, :class_name => 'SLS::Project'
    has_many :assignments, :class_name => 'SLS::Assignment', :as => :subject
    has_many :tickets, :class_name => 'SLS::Ticket', :through => :assignments,
      :as => :assignable, :source => :subject, :source_type => 'SLS::Label'
  end

  class Assignment < ActiveRecord::Base
    belongs_to :subject, :polymorphic => true
    belongs_to :assignable, :polymorphic => true
  end

  class Activity < ActiveRecord::Base
    belongs_to :subject, :polymorphic => true
    belongs_to :activity, :polymorphic => true
  end
end