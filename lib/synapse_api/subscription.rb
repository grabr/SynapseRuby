module Synapse
	class Subscription
		attr_reader :subscription_id, :url, :payload

		def self.from_response(response)
			self.new(
				subscription_id: response['_id'],
				url: response['url'],
				payload: response
			)
		end

		def initialize(subscription_id:, url:, payload:)
			@subscription_id = subscription_id
			@url = url
      @payload = payload
		end
	end
end
