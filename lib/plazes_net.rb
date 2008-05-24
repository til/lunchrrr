require 'tzinfo'

module PlazesNet

  class Base < ActiveResource::Base
    self.logger = Logger.new($stderr) # output all http requests and responses
  end

  class Presence < Base
    
    def url
      "http://plazes.net/presences/#{self.id}"
    end

    def scheduled_at_local
      TZInfo::Timezone.get(plaze.timezone).utc_to_local(scheduled_at)
    end
  end

  class Plaze < Base
    def url
      "http://plazes.net/plazes/#{self.id}"
    end
  end
end
