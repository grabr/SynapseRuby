module Synapse
	class Transaction
		attr_accessor :trans_id, :payload, :node_id, :user

		def self.from_response(response, node_id: nil)
			self.new(
				trans_id: response['_id'],
				payload: response,
				node_id: node_id
			)
		end

		def initialize(trans_id:, payload:, node_id: nil, user: nil)
			@trans_id = trans_id
			@payload = payload
      @node_id = node_id
      @user = user
		end
	end
end
