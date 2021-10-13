module Synapse
	class Subscriptions
		attr_reader :subscriptions_count, :page, :limit, :payload, :page_count

		def self.from_response(response)
			return [] if response['subscriptions'].empty?

			subscriptions = response['subscriptions'].map do |data|
				Subscription.from_response(data)
			end

			self.new(
				limit: response['limit'],
				page: response['page'],
				page_count: response['page_count'],
				subscriptions_count: response['subscriptions_count'],
				payload: subscriptions
			)
		end

		def initialize(page:, limit:, subscriptions_count:, payload:, page_count:)
			@subscriptions_count = subscriptions_count
			@page = page
      @limit = limit
      @payload = payload
      @page_count = page_count
		end
	end
end
