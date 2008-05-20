#!/usr/bin/env camping
require 'camping/session'
require 'oauth/consumer'
require 'hpricot'

Camping.goes :Lunchrrr

ROOT = File.dirname(__FILE__)


module Lunchrrr
  include Camping::Session

  SITE = "http://localhost"
  def self.consumer
    OAuth::Consumer.new(
      "oQbNNidXpyhoh7X7wBV4Q",
      "2odz7J8kQyB52kI2Bxu97w7QyZEZ5zAwReBp1M",
      :site => SITE
      )
  end
  
  def self.access_token
    OAuth::AccessToken.new(Lunchrrr.consumer, '7BcnNYsxuSyhtVxStfPw', 'X0H0cK8mKtKMTlqbPhlZyiQIvlSQva3B0GuyDuaH91Q')
  end
end


module Lunchrrr::Controllers
  
  class When < R '/'
    def get
      render :when
    end
  end

  class Where < R '/where'
    def get
      @restaurants = Hpricot(Lunchrrr.access_token.get('/plazes.xml?limit=5&q=restaurant').body).
        search('plaze').map do |fruit|
        %w[name address id].inject({}) { |memo, key| memo[key] = fruit.at(key).inner_html; memo }
      end

      render :where
    end
  end
  
  class Lunched < R '/lunched'
    def get
      render :lunched
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
        link :rel => 'stylesheet', :type => 'text/css', :href => '/static/style.css'
      end
      body do
        self << yield
      end
    end
  end

  def when
    h1 'Lunch at?'
    form :method => :get, :action => '/where' do
      input.earlier! :type => :submit, :value => '-'
      input :value => '1 PM', :size => 5
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
          form.here :method => :get, :action => 'lunched' do
            input :type => :submit, :value => restaurant['name']
            text restaurant['address']
          end
        end
      end
    end
  end
  
  def lunched
    h1 "Lunch'd"
    p { "Done! Happy lunching at #{a 'florianihof', :href => 'http://plazes.net/plazes/12345'} on 1:30PM" }
    h2 "Invite for lunch"
    form do
      textarea { }
      input :type => :submit, :value => 'Send nag mail'
    end
  end
end
