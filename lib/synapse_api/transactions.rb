module Synapse
	class Transactions
		attr_reader :page, :page_count, :limit, :payload, :trans_count

		def self.from_response(response, node_id: nil)
			return [] if response['trans'].empty?

			trans = response['trans'].map do |data|
				Transaction.from_response(data, node_id: node_id)
			end

			self.new(
				limit: response['limit'],
				page: response['page'],
				page_count: response['page_count'],
				trans_count: response['trans_count'],
				payload: trans
			)
		end

		def initialize(page:, limit:, trans_count:, payload:, page_count:)
			@page = page
			@limit = limit
			@trans_count = trans_count
			@payload = payload
      @page_count = page_count
		end
	end
end
