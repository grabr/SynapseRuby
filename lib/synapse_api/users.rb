module Synapse
	class Users
		attr_reader :page, :page_count, :limit, :http_client, :payload, :user_count

		def self.from_response(response, client:, **options)
			return [] if response['users'].empty?

			users = response['users'].map do |data|
				User.from_response(data, client: client, **options)
			end

			self.new(
				limit: response['limit'],
				page: response['page'],
				page_count: response['page_count'],
        user_count: response['users_count'],
        payload: users,
        http_client: client
			)
		end

		def initialize(page:, page_count:, limit:, http_client:, payload:, user_count:)
			@http_client = http_client
			@page = page
			@page_count = page_count
			@limit = limit
			@user_count = user_count
			@payload = payload
		end
	end
end
