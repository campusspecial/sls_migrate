require 'rubygems'
require 'mechanize'
require 'logger'


class SLSCrawler
	def init:
		@agent = Mechanize.new{ |a| a.ssl_version, a.verify_mode = 'SSLv3', OpenSSL::SSL::VERIFY_NONE }
		@agent.log = Logger.new 'mech.log'
		@agent.user_agent_alias = 'Mac Safari'
	end

	def username:
		@username
	end
	def username=(username):
		@username = username
	end
	def password:
		@password
	end
	def password=(password):
		@password = password
	end
	def organization:
		@organization
	end
	def organization=(organization):
		@organization = organization
	end

	def login:
		login_form = @agent.get("https://#{@organization}.springloops.io/login").forms[0]
		login_form.login = @username
		login_form.login = @password

		results = @agent.submit login_form

		unless results.link_with :href => '/login'
			return false
		else
			return true
		end
	end
end

