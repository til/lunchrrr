#!/usr/bin/env camping
require 'camping/session'
require 'oauth/consumer'
require 'hpricot'
require 'socket'
require 'lib/active_resource_with_oauth'

require 'lib/plazes_net'

Camping.goes :Lunchrrr

ROOT = File.dirname(__FILE__)

case Socket.gethostname
when 'sandbox'
  SITE = "https://plazes.net"
  CONSUMER = OAuth::Consumer.new(
    "BqwUVF0WYc9BnfXEa8N6Hg",
    "Xqc8n78RnNvc0EPclTw6ecBS4J9Nwpvq7MMyFwB3leY",
    :site => SITE
  )
else # localhost
  SITE = "http://localhost"
  CONSUMER = OAuth::Consumer.new(
    "5qOoKfNlyfI9afwTTGJpiw",
    "p9eg7KMQZnoOyJ7FzbrBgO6uxt5yVSRxWO5Zkp1KM",
    :site => SITE
  )
end

PlazesNet::Base.site = SITE

module Lunchrrr::RequireAuth

  def service(*args)
    if self.class.to_s !~ /(Static|Identify)$/
      if !@state.access_token
        redirect '/identify' and return self
      end
    end

    PlazesNet::Base.token = @state.access_token
    super(*args)
  end
end


module Lunchrrr
  include Camping::Session, Lunchrrr::RequireAuth
end

def Lunchrrr.create
  Camping::Models::Session.create_schema
end

class PlazesNet::Presence
  
  def self.find_next_lunch
    find(:one, :from => '/me/presence.xml')
  end
end


module Lunchrrr::Controllers
  
  class Start < R '/'

    def get
      if @presence = PlazesNet::Presence.find_next_lunch
        render :lunched
      else
        render :when
      end
    end
  end


  class When < R '/when'

    def post
      @state.time = @input.time
      redirect '/where'
    end
  end

  class Where < R '/where'
    def get
      @restaurants = Hpricot(@state.access_token.get('/plazes.xml?limit=5&q=restaurant').body).
        search('plaze').map do |fruit|
        %w[name address id].inject({}) { |memo, key| memo[key] = fruit.at(key).inner_html; memo }
      end

      render :where
    end

    
    def post
      @state.access_token.post('/presences', { 
          :presence => { :plaze_id => @input.plaze_id, 
            :status => "lunchrrr",
            :scheduled_at => @state.time,
            :scheduled_at_is_plaze_local => true
          }
        }.to_query)
      redirect '/'
    end
  end
  
  class Static < R '/static/([a-z0-9]+\.[a-z]+)'
    def get(file)
      return File.read(File.join(ROOT, 'static', file))
    end
  end

  class Identify < R '/identify'
    def get
      if @state.access_token
        # Everything fine
        return redirect('/')
      end

      if @state.request_token && @input['oauth_token']
        # Redirected from service provider
        @state.access_token = @state.request_token.get_access_token
        @state.request_token = nil
        return redirect('/')
      end

      if !@state.request_token
        @state.request_token = CONSUMER.get_request_token
      end

      @authorize_url = @state.request_token.authorize_url <<
        "&oauth_callback=" <<
        CGI::escape("http://#{env['HTTP_HOST']}/identify")
      render :identify
    end
  end
end


module Lunchrrr::Views
  def layout
    html do
      head do
        script :src => '/static/jquery.js'
        link :rel => 'stylesheet', :type => 'text/css', :href => '/static/style.css'
      end
      body do
        self << yield
      end
    end
  end

  def identify
    h1 'Who are you?'
    p "You need to have an account at plazes.net."
    p { "Go there now: <em>#{a 'plazes.net', :href => @authorize_url}</em>" }
    p "No worries, it will send you back here quickly."
  end

  def when
    h1 'Lunch at?'
    form :method => :post, :action => '/when' do
      input.earlier! :type => :submit, :value => '-'
      input :name => :time, :value => '14:00', :size => 5
      input.later! :type => :submit, :value => '+'
      br
      input :type => :submit, :value => 'OK!'
    end
  end
  
  def where
    h1 'Where?'
    
    ul do
      @restaurants.each do |restaurant|
        li do
          form.here :method => :post, :action => '/where' do
            input :type => :hidden, :value => restaurant['id'], :name => 'plaze_id'
            input :type => :submit, :value => restaurant['name']
            text restaurant['address']
          end
        end
      end
    end
  end
  
  def lunched
    h1 "Yo Lunch"
    p do
      text "At #{a @presence.plaze.name, :href => @presence.plaze.url} on #{@presence.scheduled_at_local.strftime('%H:%M')} "
      a.unimportant "(change)", :href => @presence.url
    end
    h2 "Invite for lunch"
    form do
      textarea { }
      input :type => :submit, :value => 'Send nag mail'
    end
  end
end
