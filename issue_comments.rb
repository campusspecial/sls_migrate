require 'rubygems'
require 'mechanize'
require 'logger'


class SLSCrawler
    attr_writer :password
    attr_accessor :username, :organization, :agent

	def initialize
		@agent = Mechanize.new{ |a| a.ssl_version, a.verify_mode = 'SSLv3', OpenSSL::SSL::VERIFY_NONE }
		@agent.log = Logger.new 'mech.log'
		@agent.user_agent_alias = 'Mac Safari'
	end

    def base_url
        "https://#{@organization}.springloops.io"
    end

	def login
        page = @agent.get(self.base_url + "/login")
        unless page.link_with(:href => '/logout').nil?
            return true
        end
        login_form = page.forms[0]
		login_form.login = @username
		login_form.password = @password

		results = @agent.submit login_form

		unless results.link_with :href => '/logout'
			return false
		else
			return true
		end
	end

    def get_comments project_id, ticket_id
        params = {
            'ticketId' => '0',
            'projectId' => project_id.to_s,
            'relativeId' => ticket_id.to_s
        }
        JSON.parse(@agent.get(self.base_url + "/ajax/fetch-ticket.html", params))
    end
end

