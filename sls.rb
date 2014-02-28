#!/usr/bin/env ruby
require 'date'
require 'rubygems'
require 'mechanize'
require 'logger'
require 'json'
require 'dm-core'
require 'dm-migrations'

DataMapper::Logger.new($stdout, :debug)
DataMapper.setup(:default, 'sqlite::memory:')

class SLSCrawler
    attr_writer :password
    attr_accessor :username, :organization, :agent

    def initialize
        @agent = Mechanize.new do |a|
            a.log = Logger.new 'sls_crawler.log'
            a.log.level = Logger::INFO
            a.user_agent_alias = 'Mac Safari'
            a.ssl_version = 'SSLv3'
            a.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
    end

    def base_url
        "https://#{@organization}.springloops.io"
    end

    def login
        page = @agent.get(self.base_url + "/login")
	return false if page.nil?
        return true unless page.link_with(:href => '/logout').nil?

        login_form = page.forms[0]
        login_form.login = @username
        login_form.password = @password

        results = @agent.submit login_form

        if results.link_with(:href => '/logout').nil?
            return false
        else
            return true
        end
    end

    def fetch_ticket_info project_id, ticket_id
        params = {
            'ticketId' => '0',
            'projectId' => project_id.to_s,
            'relativeId' => ticket_id.to_s
        }
        data = JSON.parse(@agent.get(self.base_url + "/ajax/fetch-ticket.html", params), :symbolize_names => true)
        if data[:success]
            ticket = SLSTicket.new data[:ticket]
            data[:ticket][:updates].each do |update|
                ticket.comment SLSComment.new do |c|
                    c.comment = update[:comment]
                    c.sls_id = update[:id]
                    if update[:statusUpdate]
                        c.status_change = SLSStatusChange.new do |change|
                            change.name = update[:statusUpdate][:new][:name]
                            change.is_open = update[:statusUpdate][:new][:isOpen]
                        end
                    end
                end
            end
            ticket
        else
            return nil
        end
    end

    def fetch_projects
        data = JSON.parse(@agent.get(self.base_url + '/ajax/projects-fetch-stacked-stats.json').body, :symbolize_names => true)
        project_ids = Array.new
        data[:result].keys.each do |proj|
            project_ids.push proj.to_s.to_i
        end
        project_ids
    end

    def fetch_account_info
        return nil
        #page = @agent.get(self.base_url + '/project/'+project_id+'/tasks').body
        #html_doc = Nokogiri::HTML(page)
        #script_tag = html_doc.css('head > script')[1]
        
        # cannot parse json in this area because it is invalid! (single quotes
        # instead of double quotes)
        #JSON.parse(script_tag.scan(/\$\.wsf\.setValue\(\s*['"]account['"]\s*,\s*\{.*'aggregateData'\s*:\s*'(\{.*\})'.*\}\s*\)\s*;/)[0][0])
    end

    def fetch_tickets
        post_params = Hash.new
        project_data = JSON.parse(@agent.get(self.base_url + '/ajax/get-public-task-reports.json', {'projectId' => project_id}).body, :symbolize_names => true)
        # find "all tasks" even if it's not the first one
        project_data[:result].each do |pdata|
            if pdata[:name].downcase == 'export'
                #grab counter data
                pdata[:counters].each do |c_key, c_value|
                    c_value.each do |key, value|
                        post_params['report[counters]['+c_key+']['+key+']'] = value
                    end
                end
                if pdata[:parentId] == 0
                    post_params['report[parentId]'] = pdata[:id]
                else
                    post_params['report[parentId]'] = pdata[:parentId]
                end
                post_params['report[viewer]'] = pdata[:owner]
                pdata[:layout].each do |key, value|
                    unless value.nil?
                        post_params['report[layout]['+key+']'] = value
                    end
                end
                post_params['report[filters][PROJECT][projects][0][id]'] = project_id
                post_params['report[filters][PROJECT][projects][0][name]'] = ''
                #
                break
            end
        end
        data = JSON.parse(@agent.post(self.base_url + '/ajax/request-method.json', post_params).body, :symbolize_names => true)
        data
    end
end

