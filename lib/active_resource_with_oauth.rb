# From https://agree2.com/masters/c1ec256461f793339a2c8161f091cac559906dcf.rb

# This API is licensed under the MIT LICENSE:
#
# Copyright (c) 2007 Extra Eagle LLC
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

require 'activeresource'

module ActiveResource
  class Base    
    class << self
      # Get the Token set either locally or in it's parent class
      def token
        if defined?(@token)
          @token
        elsif superclass != Object && superclass.token
          @token=superclass.token.dup.freeze
        end
      end
      
      # Set the OAuth AccessToken
      def token=(token)
        @token=token
      end
      
      # We need to override Connection so we can set the token on it
      def connection(refresh = false)
        if defined?(@connection) || superclass == Object
          @connection = Connection.new(site, format) if refresh || @connection.nil?
          @connection.token=token if token
          @connection
        else
          superclass.connection
        end
      end
    end
  end
  
  class Connection
    attr_accessor :token
    # Sets authorization header
    def request_with_oauth(method, path, *arguments)
      if @token
        @token.consumer.site=site
        logger.info "#{method.to_s.upcase} #{site.scheme}://#{site.host}:#{site.port}#{path}" if logger
        result = nil
        time = Benchmark.realtime { result =@token.send(method, path, *arguments) }
        logger.info "--> #{result.code} #{result.message} (#{result.body ? result.body : 0}b %.2fs)" % time if logger
        handle_response(result)
      else
        request_without_oauth(method,path,*arguments)
      end
    end
    
    alias_method_chain :request, :oauth
    
  end
end
