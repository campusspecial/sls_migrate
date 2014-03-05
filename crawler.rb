#!/usr/bin/env ruby
# vim: ts=2:tw=2:sw=2:expandtab
# vi: ts=2:tw=2:sw=2:expandtab

require 'rubygems'
require 'mechanize'
require 'logger'
require 'json'
require 'date'

module SLS

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
      @login_attempts = 0
    end

    def base_url
      "https://#{@organization}.springloops.io"
    end

    def logged_in?
      if @login_attempts > 2
        raise 'Maxed out on login attempts'
      end
      @logged_in
    end

    def login force=false
      begin
        return @logged_in unless force or not @logged_in
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
      self.login unless self.logged_in?
      begin
        params = {
          'ticketId' => '0',
          'projectId' => project_id.to_s,
          'relativeId' => ticket_id.to_s
        }
        data = JSON.parse(
          @agent.get(self.base_url + "/ajax/fetch-ticket.html", params).body,
          :symbolize_names => true
        )
        raise 'request failed' unless data[:success] and not data[:ticket].empty?
        return data[:ticket]
      rescue
        return nil
      end
    end

    def fetch_projects
      self.login unless self.logged_in?
      begin
        data = JSON.parse(
          @agent.get(self.base_url + '/ajax/projects-fetch-stacked-stats.json').body,
          :symbolize_names => true
        )
        raise 'invalid server response' if data[:result].keys.empty?
        project_ids = Array.new
        data[:result].keys.each {|proj| project_ids.push proj.to_s.to_i}
        return project_ids
      rescue
        return nil
      end
    end
  end
end
