module Synapse
	class Nodes
		attr_reader :page, :page_count, :limit, :payload, :nodes_count

		def self.from_response(response, **options)
			return [] if response['nodes'].empty?

			nodes = response['nodes'].map do |data|
				Node.from_response(data, **options)
			end

			self.new(
				limit: response['limit'],
				page: response['page'],
				page_count: response['page_count'],
				nodes_count: response['nodes_count'],
				payload: nodes
			)
		end

		def initialize(page:, limit:, page_count:, nodes_count:, payload:)
			@page = page
			@limit = limit
			@nodes_count = nodes_count
			@page_count = page_count
			@payload = payload
		end
	end
end
