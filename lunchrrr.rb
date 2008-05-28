#!/usr/bin/env camping
#
# A small example app that uses plazes.net. In particular it
# demonstrates:
#
# - use of the ability to create presences in the future to express
#   the intention of a user to be at a certain location at a certain
#   time (to have lunch in this case)
#
# - the personalized suggestions that plazes.net delivers for
#   particular users based on where they were before. This results in
#   a relevant list after a couple of times used
#
# - authentication via oauth and ActiveResource, using a monkey patch
#   to ActiveResource from agree2.com
#
# Online at http://lunchrrr.com
#
# This Software is licensed under the MIT LICENSE:
#
# Copyright (c) 2008 Plazes
# 
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

require 'camping/session'
require 'oauth/consumer'
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
when 'sam'
  SITE = "http://localhost"
  CONSUMER = OAuth::Consumer.new(
    "oQbNNidXpyhoh7X7wBV4Q",
    "2odz7J8kQyB52kI2Bxu97w7QyZEZ5zAwReBp1M",
    :site => SITE
  )
else # laptop
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
    if self.class.to_s !~ /(Static|Identify|Error)$/
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
  
  def self.find_todays_lunch
    # Fing the next future presence that has 'lunch' in its status
    # message. TODO also look into past presences, limit to actual day
    # instead of 24h into the future
    find(:all, :from => '/me/future_presences.xml').detect do |presence|
      presence.scheduled_at < 1.day.from_now && presence.status =~ /lunch/i
    end
  end
end

module Lunchrrr::Controllers
  
  class Start < R '/'

    def get
      if @presence = PlazesNet::Presence.find_todays_lunch
        render :lunched
      else
        render :when
      end
    end
  end


  class When < R '/when'

    def get
      # Useful mostly for testing
      render :when
    end

    def post
      @state.time = @input.time
      redirect '/where'
    end
  end

  class Where < R '/where'

    def get
      
      @restaurants = PlazesNet::Plaze.find(:all, :params => {
          :q => "restaurant #{@input.q}",
          :limit => @input.q.blank? ? 5 : 50, 
      })

      render :where
    end

    def post
      # Find the current time in the timezone of the plaze that the
      # user just posted
      now_plaze_local = TZInfo::Timezone.get(PlazesNet::Plaze.find(@input.plaze_id).timezone).
                          utc_to_local(Time.now.utc)
      
      # Parse time from input. TODO use some funky time parsing lib to
      # understand more formats
      hour, minute =  @state.time.split(':')
      
      # Transform the current time from above by setting hour and
      # minute to what the user posted. Even though it says 'utc'
      # here, the resulting Time instance is actually in plaze local
      # time (rubys' timezone support is somewhat lacking for doing
      # these kind things)
      scheduled_at = Time.utc(
        now_plaze_local.year, now_plaze_local.month, now_plaze_local.day, hour, minute, 0
      )
      
      # Make sure the time is in the future
      if scheduled_at < now_plaze_local
        scheduled_at += 1.day
      end

      # Create the lunch presence
      PlazesNet::Presence.create(
        :plaze_id => @input.plaze_id, 
        :status => "lunchrrr",
        :scheduled_at => scheduled_at,
        :scheduled_at_is_plaze_local => true
      )
      redirect '/'
    end
  end
  
  class Invite < R '/invite'
    def post
      @input.addresses.split(',').each do |address|
        # TODO send an email
      end

      redirect '/'
    end
  end

  class Identify < R '/identify'
    def get
      if @state.access_token
        # Everything fine
        return redirect('/')
      end

      if @state.request_token && @input['oauth_token']
        # The service provider (plazes.net) redirected here
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

  class Static < R '/static/([a-z0-9]+\.[a-z]+)'
    def get(file)
      return File.read(File.join(ROOT, 'static', file))
    end
  end
end


module Lunchrrr::Views
  def layout
    html do
      head do
        script :src => '/static/jquery.js'
        script :src => '/static/lunchrrr.js'
        link :rel => 'stylesheet', :type => 'text/css', :href => '/static/style.css'
      end
      body do
        self << yield
      end
    end
  end

  def identify
    h1 'Before lunch'
    p "You need to have an account at plazes.net."
    p { "Go there now: <em>#{a 'plazes.net', :href => @authorize_url}</em>" }
    p "No worries, it will send you back here quickly."
  end

  def when
    h1 'Lunch at?'
    form.when :method => :post, :action => '/when' do
      input.time! :name => :time, :value => '14:00', :size => 5
      br
      input :type => :submit, :value => 'OK!'
    end
  end
  
  def where
    h1 'Where?'
    
    ul do
      @restaurants.each do |restaurant|
        li.where do
          form.where :method => :post, :action => '/where' do
            input :type => :hidden, :value => restaurant.id, :name => 'plaze_id'
            input :type => :submit, 
                  :value => [restaurant.name, restaurant.address].
                              reject(&:blank?).join(', ')
          end
        end
      end
    end
    form.search :method => :get, :action => '/where' do
      label 'None of these! Find me another one: ', :for => :q
      input.q! :name => 'q', :value => @input.q
      input :type => :submit, :value => 'Search'
    end
  end
  
  def lunched
    h1 "Lunch at"
    p.lunch_at do
      a @presence.plaze.name, :href => @presence.plaze.url
      text " on "
      text @presence.scheduled_at_plaze_local.strftime('%H:%M')
      text " "
      a.unimportant "(change)", :href => @presence.url
    end
    #h2.invite "Invite someone"
    #form.invite :method => :post, :action => '/invite' do
    #  textarea(:name => :addresses, :cols => 40, :rows => 5) { }
    #  br
    #  input :type => :submit, :value => 'Send nag mail'
    #end
  end
end

Camping::Reloader.database = { 
  :adapter => 'sqlite3', 
  :database => File.join(ROOT, 'lunchrrr.db')}
