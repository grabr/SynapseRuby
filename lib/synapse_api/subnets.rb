module Synapse
  class Subnets
    attr_accessor  :page, :page_count, :limit, :payload, :subnets_count, :node_id

    def self.from_response(response)
      subnets = response['subnets'].map do |data|
        Subnet.from_response(data)
      end

      self.new(
        limit: response['limit'],
        page: response['page'],
        page_count: response['page_count'],
        subnets_count: response['subnets_count'],
        payload: subnets,
        node_id: response['node_id']
      )
    end

    def initialize(limit:, page:, page_count:, subnets_count:, payload:, node_id:)
      @page = page
      @limit = limit
      @subnets_count = subnets_count
      @payload = payload
      @page_count = page_count
      @node_id = node_id
    end
  end
end
