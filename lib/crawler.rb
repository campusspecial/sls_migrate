#!/usr/bin/env ruby
# vim: ts=2:tw=2:sw=2:expandtab
# vi: ts=2:tw=2:sw=2:expandtab

require 'rubygems'
require 'mechanize'
require 'logger'
require 'json'
require 'date'

module SLS

  class CrawlerException < Exception
  end

  def self.ajax_import_ticket_info(args)
    raise SLS::CrawlerException, "Crawler must be initialized as $bot" unless $bot.is_a? SLS::Crawler
    args[:tickets].each do |ticket|
      was_set = {
        :status => false,
        :labels => false,
        :owner => false,
        :body => false,
        :title => false,
        :timestamp => false,
        :priority => false,
        :comments => false,
        :workers => false
      }
      begin
        data = $bot.fetch_ticket_info ticket.project.sls_id, ticket.sls_id
        sleep 1
        ticket.title = data[:title]
        was_set[:title] = true
        if data[:hasDescription]
          ticket.body = data[:desc]
          was_set[:body] = true
        end
        ticket.created = Time.at(data[:created]).utc.to_datetime
        was_set[:timestamp] = true
        ticket.priority = data[:priority][:name]
        was_set[:priority] = true
        ticket.owner = SLS::User.from_json(data[:opener])
        was_set[:owner] = true
        ticket.save
        # milestone
        # labels
        data[:ticketLabels].each do |label|
          ticket.add_label SLS::Label.from_json(label, ticket.project)
          was_set[:labels] = true
        end
        # assigned workers
        data[:assignment].each do |worker|
          ticket.add_worker SLS::User.from_json(worker)
          was_set[:workers] = true
        end
        # ticket activity
        data[:updates].each do |update|
          owner = SLS::User.from_json(update[:owner])
          # status changes
          unless update[:statusUpdate].nil?
            # Make sure to set the initial status
            if not was_set[:status]
              ticket.change_status update[:statusUpdate][:old][:name], ticket.owner
              was_set[:status] = true
            end
            ticket.change_status update[:statusUpdate][:new][:name], owner
          end
          # comments
          unless update[:comment].nil?
            ticket.add_comment(
              update[:comment],
              owner,
              update[:id],
              Time.at(update[:created]).utc.to_datetime
            )
            was_set[:comments] = true
          end
        end
        unless was_set[:status]
          ticket.change_status data[:status][:name], ticket.owner
          was_set[:status] = true
        end
        ticket.save
      rescue SLS::CrawlerException => e
        puts e.message
      end
      puts "Ticket #{ticket.sls_id}:"
      was_set.keys.each {|done| puts "   + #{done.to_s.capitalize}" if was_set[done]}
      was_set.keys.each {|done| puts "   ! #{done.to_s.capitalize}" unless was_set[done]}
    end
  end

  class Label
    def self.from_json(json, project)
      SLS::Label.where(
        :sls_id => json[:id]
      ).first_or_create do |l|
        l.name = json[:name]
        l.project = project
      end
    end
  end

  class User
    def self.from_json(json)
      SLS::User.where(
        :sls_id => json[:id]
      ).first_or_create do |u|
        u.f_name = json[:firstName]
        u.l_name = json[:lastName]
        u.email = json[:email]
        u.short_name = json[:shortName]
      end
    end
  end

  class Crawler
    attr_writer :password
    attr_accessor :username, :organization, :agent

    def initialize args
      @agent = Mechanize.new do |a|
        a.log = Logger.new 'sls_crawler.log'
        a.log.level = Logger::INFO
        a.user_agent_alias = 'Mac Safari'
        a.ssl_version = 'SSLv3'
        a.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      @username = args[:username] unless args[:username].nil? or args[:username].empty?
      @password = args[:password] unless args[:password].nil? or args[:password].empty?
      @organization = args[:organization] unless args[:organization].nil? or args[:organization].empty?
      @logged_in = false
      @login_attempts = 0
    end

    def base_url
      "https://#{@organization}.springloops.io"
    end

    def logged_in?
      if @login_attempts > 2
        raise SLS::CrawlerException, 'Maxed out on login attempts'
      end
      @logged_in === true
    end

    def login force=false
      begin
        return self.logged_in? unless force or not self.logged_in?
        page = @agent.get(self.base_url + "/login")
        raise 'Unable to reach springloops' if page.nil?
        return true unless page.link_with(:href => '/logout').nil?

        login_form = page.forms[0]
        login_form.login = @username
        login_form.password = @password

        results = @agent.submit login_form

        raise 'login attempt failed' if results.link_with(:href => '/logout').nil?
        @logged_in = true
        @login_attempts = 0
      rescue
        @logged_in = false
        @login_attempts += 1
      end
      return @logged_in
    end

    def fetch_ticket_info project_id, ticket_id
      self.login while not self.logged_in?
      params = {
        'ticketId' => '0',
        'projectId' => project_id.to_s,
        'relativeId' => ticket_id.to_s
      }
      page = @agent.get(self.base_url + "/ajax/fetch-ticket.html", params)
      raise SLS::CrawlerException, 'Empty response' if page.body.empty?
      data = JSON.parse(page.body,:symbolize_names => true)
      raise SLS::CrawlerException, "Request failed. \"#{data[:message]}\"" unless data[:success] and not data[:ticket].empty?
      return data[:ticket]
    end

    def fetch_projects
      self.login while not self.logged_in?
      page = @agent.get(self.base_url + '/ajax/projects-fetch-stacked-stats.json')
      raise SLS::CrawlerException, "No response when fetching projects." if page.body.empty?
      data = JSON.parse(page.body,:symbolize_names => true)
      raise SLS::CrawlerException, "Invalid server response when fetching projects." if data[:result].keys.empty?
      project_ids = Array.new
      data[:result].keys.each {|proj| project_ids.push proj.to_s.to_i}
      return project_ids
    end
  end
end
