module Synapse
	class Node
		attr_reader :node_id, :user_id, :payload, :full_dehydrate, :type

		def self.from_response(response, **options)
			self.new(
				node_id: response['_id'],
				user_id: response['user_id'],
				payload: response,
				full_dehydrate: options[:full_dehydrate] == 'yes',
				type: response['type']
			)
		end

		def initialize(node_id:, user_id:, payload:, full_dehydrate:, type: nil)
			@node_id = node_id
			@full_dehydrate = full_dehydrate
			@user_id = user_id
			@payload = payload
      @type = type
		end
	end
end
