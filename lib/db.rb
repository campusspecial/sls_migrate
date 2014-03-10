#!/usr/bin/env ruby
# vim: ts=2:tw=2:sw=2:expandtab
# vi: ts=2:tw=2:sw=2:expandtab

require 'rubygems'
require 'sqlite3'
require 'active_record'
require 'yaml'
require './lib/runtime_fixes'
require 'active_support/core_ext/integer/inflections'

module SLS
  def self.import_ticket_nums(project, filename)
    if project.is_a? SLS::Project
      proj = project
    else
      proj = SLS::Project.where(:name => project_name).first
    end
    File.readlines(filename).each do |line|
      num = line.chomp.scan(/^(\d+),/)
      unless num.empty?
        SLS::Ticket.find_or_create_by(
          :sls_id => num[0][0].to_i,
          :project_id => proj.id
        )
      end
    end
    nil
  end

  def self.cleanup_db
    config = YAML::load(File.open('database.yml')).symbolize_keys
    begin
      File.delete(config[:database])
    rescue
    end
    self.import_table_schema
  end

  def self.import_table_schema
    ActiveRecord::Base.establish_connection(YAML::load(File.open('database.yml')))
    ActiveRecord::Schema.define do
      unless ActiveRecord::Base.connection.tables.include? 'tickets'
        create_table :tickets do |table|
          table.string :title
          table.text :body
          table.string :priority, :default => 'Normal'
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
        # Many-to-many facilitator
        create_table :assignments do |table|
          table.integer :subject_id, :null => false
          table.string :subject_type, :null => false
          table.integer :assignable_id, :null => false
          table.string :assignable_type, :null => false
        end
      end

      unless ActiveRecord::Base.connection.tables.include? 'activities'
        # Many-to-many facilitator
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
          table.integer :author_id, :null => false
        end
      end

      unless ActiveRecord::Base.connection.tables.include? 'labels'
        create_table :labels do |table|
          table.string :name, :null => false
          table.integer :project_id, :null => false
          table.integer :github_id
          table.integer :sls_id
        end
      end
    end
  end


  class Ticket < ActiveRecord::Base
    belongs_to :project, :class_name => 'SLS::Project'
    belongs_to :owner, :class_name => 'SLS::User'

    # Assignments
    has_many :assignments,
      :class_name => 'SLS::Assignment',
      :as => :subject

    has_many :workers,
      :class_name => 'SLS::User',
      :through => :assignments,
      :as => :assignable,
      :source => :assignable,
      :source_type => 'SLS::User'

    has_many :labels,
      :class_name => 'SLS::Label',
      :through => :assignments,
      :as => :assignable,
      :source => :assignable, 
      :source_type => 'SLS::Label'


    # Activities
    has_many :activities,
      :class_name => 'SLS::Activity',
      :as => :subject

    has_many :status_changes,
      :class_name => 'SLS::StatusChange',
      :as => :activity,
      :through => :activities,
      :source => :activity,
      :source_type => 'SLS::StatusChange'

    has_many :comments,
      :class_name => 'SLS::Comment',
      :through => :activities,
      :as => :activity,
      :source => :activity,
      :source_type => 'SLS::Comment'

    def add_worker(user)
      self.add_assignment user if user.is_a? SLS::User and not self.workers.include? user
    end

    def remove_worker(user)
      self.remove_assignment if user.is_a? SLS::User and self.workers.include? user
    end

    def add_label(label)
      self.add_assignment label if label.is_a? SLS::Label and not self.labels.include? label
    end

    def remove_label(label)
      self.remove_assignment label if label.is_a? SLS::Label and self.labels.include? label
    end

    def change_status(status, author)
      SLS::StatusChange.create(
        :status => status,
        :ticket => self,
        :author => author,
        :open => (not ['resolved','closed'].include? status.downcase)
      )
    end

    def status
      self.status_changes.last
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

    def add_assignment(tag)
      SLS::Assignment.create(:subject => self, :assignable => tag)
      tag.reload
      self.reload
    end
    def remove_assignment(tag)
      SLS::Assignment.where(:subject => self, :assignable => tag).first.destroy
      tag.reload
      self.reload
    end

    def export_body
      ghbody = Array.new
      unless $ghconfig.nil?
        ghbody += [$ghconfig[:export_header],""] unless $ghconfig[:export_header].nil?
        slsworkers = self.workers.map {|user| user.email}
        ghworkers = $ghconfig[:users].map {|u| u[:github_username] if slsworkers.include? u[:sls_email]}
      end
      parsed_body = ReverseMarkdown.parse self.body.filter_html_crap
      parsed_body = parsed_body.split("\n\n").reject {|s| s.trim.empty?}
      ghbody += parsed_body
      ghbody += [""]

      ghbody += ["/cc #{ghworkers.join(' ')}"] unless ghworkers.nil? or ghworkers.empty?

      ghbody += ["## Metadata:"]
      ghbody += ["Created by #{self.owner.full_name} on #{self.created.in_time_zone('Eastern Time (US & Canada)').strftime("%a, %B #{self.created.in_time_zone('Eastern Time (US & Canada)').day.ordinalize}, %Y at %l:%M%P %Z")}"]
      return ghbody.join("\n\n")
    end
    def export_title
      self.title
    end
    def export_labels
      ghlabels = self.labels.map {|label| label.name}
      # Status? (Huboard)
      ghlabels += case self.status.status.downcase
                  when 'closed'
                    []
                  when 'open'
                    ["0 - Backlog"]
                  when 'in progress'
                    ["2 - Working"]
                  when 'resolved'
                    ["3 - Done"]
                  end
      # Others?
      return ghlabels.join(',')
    end
    def export_activity
      nil
    end
  end

  class Project < ActiveRecord::Base
    has_many :tickets, :class_name => 'SLS::Ticket'
  end

  class User < ActiveRecord::Base
    has_many :creations, :class_name => 'SLS::Ticket'
    has_many :assignments, :class_name => 'SLS::Assignment', :as => :assignable

    has_many :tasks, :class_name => 'SLS::Ticket', :through => :assignments,
      :as => :assignable, :source => :subject, :source_type => 'SLS::Ticket'
    has_many :comments, :class_name => 'SLS::Comment', :foreign_key => :author_id

    def full_name
      "#{self.f_name} #{self.l_name}"
    end
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

    def open?
      self.open
    end

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
    has_many :assignments, :class_name => 'SLS::Assignment', :as => :assignable
    has_many :tickets, :class_name => 'SLS::Ticket', :through => :assignments,
      :as => :subject, :source => :assignable, :source_type => 'SLS::Label'
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

#SLS::import_table_schema
