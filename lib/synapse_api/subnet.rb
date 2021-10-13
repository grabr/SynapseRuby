module Synapse
  class Subnet
    attr_accessor :subnet_id, :payload, :node_id

    def self.from_response(response)
      self.new(
        subnet_id: response['_id'],
        payload: response,
        node_id: response['node_id']
      )
    end

    def initialize(subnet_id:, payload:, node_id:)
      @subnet_id = subnet_id
      @payload = payload
      @node_id = node_id
    end
  end
end
