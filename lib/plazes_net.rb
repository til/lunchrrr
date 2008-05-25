require 'tzinfo'

module PlazesNet

  class Base < ActiveResource::Base
    self.logger = Logger.new($stdout) # output all http requests and responses

    def url
      [self.class.site.to_s.gsub(%r{/+$}, ''),
        self.class.collection_name,
        self.id].join('/')
    end
  end

  class Presence < Base

    def scheduled_at_plaze_local
      TZInfo::Timezone.get(plaze.timezone).utc_to_local(scheduled_at)
    end
    
    def method_missing(method, *args)
      case method
      when :plaze
        # Load plaze of presence when not loaded yet
        Plaze.find(self.plaze_id)
      else
        super
      end
    end
  end

  class Plaze < Base
  end
end
