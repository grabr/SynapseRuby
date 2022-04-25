# frozen_string_literal: true

# Wrapper class for /users endpoints
module Synapse
  class User
    # Valid optional args for #get
    VALID_QUERY_PARAMS = %i[query page per_page type full_dehydrate ship force_refresh is_credit
                            subnetid foreign_transaction amount].freeze

    attr_accessor :client, :user_id, :refresh_token, :oauth_key, :expires_in, :payload, :full_dehydrate

    def self.from_response(response, client:, **options)
      self.new(
        user_id: response['_id'],
        refresh_token: response['refresh_token'],
        client: client,
        full_dehydrate: options[:full_dehydrate] == 'yes',
        payload: response
      )
    end

    # @param user_id [String]
    # @param refresh_token [String]
    # @param client [Synapse::HTTPClient]
    # @param payload [Hash]
    # @param full_dehydrate [Boolean]
    def initialize(user_id:, refresh_token:, client:, payload:, full_dehydrate:)
      @user_id = user_id
      @client = client
      @refresh_token = refresh_token
      @payload = payload
      @full_dehydrate = full_dehydrate
      @base_path = "/users/#{user_id}"
    end

    # Updates users documents
    # @see https://docs.synapsefi.com/docs/updating-existing-document
    # @param payload [Hash]
    # @return [Synapse::User]
    def user_update(payload:, **options)
      response = patch("", payload, **options)
      User.from_response(response, client: client)
    end

    # Queries the API for a node belonging to user
    # @param node_id [String]
    # @param full_dehydrate [String] (optional)
    #   if true, returns all trans data on node
    # @param force_refresh [String] (optional) if true, force refresh
    #  will attempt updating the account balance and transactions on node
    # @return [Synapse::Node]
    def get_user_node(node_id:, **options)
      options[:full_dehydrate] = 'yes' if options[:full_dehydrate] == true
      options[:full_dehydrate] = 'no' if options[:full_dehydrate] == false
      options[:force_refresh] = 'yes' if options[:force_refresh] == true
      options[:force_refresh] = 'no' if options[:force_refresh] == false

      response = get("/nodes/#{node_id}", **options)
      Node.from_response(response, **options)
    end

    # Queries Synapse API for all nodes belonging to user
    # @param page [String,Integer] (optional) response will default to 1
    # @param per_page [String,Integer] (optional) response will default to 20
    # @param type [String] (optional)
    # @see https://docs.synapsepay.com/docs/node-resources node types
    # @return [Array<Synapse::Nodes>]
    def get_all_user_nodes(**options)
      response = get("/nodes", **options)
      Nodes.from_response(response, **options)
    end

    # Quaries Synapse oauth API for uto authenitcate user
    # @params scope [Array<Strings>] (optional)
    # @param idempotency_key [String] (optional)
    # @see https://docs.synapsefi.com/docs/get-oauth_key-refresh-token
    def authenticate(**options)
      payload = {
        'refresh_token' => refresh_token
      }
      payload['scope'] = options[:scope] if options[:scope]

      client.post(oauth_path, payload, **options).tap do |oauth_response|
        oauth_key = oauth_response['oauth_key']
        oauth_expires = oauth_response['expires_in']
        self.oauth_key = oauth_key
        self.expires_in = oauth_expires
        client.update_headers(oauth_key: oauth_key)
      end
    end

    # For registering new fingerprint
    # Supply 2FA device which pin should be sent to
    # @param device [String]
    # @param idempotency_key [String] (optional)
    # @see https://docs.synapsefi.com/docs/get-oauth_key-refresh-token
    # @return API response [Hash]
    def select_2fa_device(device:, **options)
      payload = {
        "refresh_token" => refresh_token,
        "phone_number" => device
      }
      path = oauth_path
      client.post(path, payload, **options)
    end

    # Supply pin for 2FA confirmation
    # @param pin [String]
    # @param idempotency_key [String] (optional)
    # @param scope [Array] (optional)
    # @see https://docs.synapsefi.com/docs/get-oauth_key-refresh-token
    # @return API response [Hash]
    def confirm_2fa_pin(pin:, **options)
      payload = {
        "refresh_token" => refresh_token,
        "validation_pin" => pin
      }

      payload['scope'] = options[:scope] if options[:scope]

      path = oauth_path

      client.post(path, payload, **options).tap do |pin_response|
        oauth_key = pin_response['oauth_key']
        oauth_expires = pin_response['expires_in']
        self.oauth_key = oauth_key
        self.expires_in = oauth_expires
        client.update_headers(oauth_key: oauth_key)
      end
    end

    # Queries the Synapse API to get all transactions belonging to a user
    # @return [Array<Synapse::Transactions>]
    # @param page [Integer] (optional) response will default to 1
    # @param per_page [Integer] (optional) response will default to 20
    def get_user_transactions(**options)
      response = get("/trans", **options)
      Transactions.from_response(response)
    end

    # Creates Synapse node
    # @note Types of nodes [Card, IB/Deposit-US, Check/Wire Instructions]
    # @param payload [Hash]
    # @param idempotency_key [String] (optional)
    # @see https://docs.synapsefi.com/docs/node-resources
    # @return [Synapse::Node] or [Hash]
    def create_node(payload:, **options)
      response = post("/nodes", payload, **options)
      Node.from_response(response['nodes'].first, **options) # ???
    end

    # Submit answer to a MFA question using access token from bank login attempt
    # @return [Synapse::Node] or [Hash]
    # @param payload [Hash]
    # @param idempotency_key [String] (optional)
    # @see https://docs.synapsefi.com/docs/add-ach-us-node-via-bank-logins-mfa
    # Please be sure to call ach_mfa again if you have more security questions
    def ach_mfa(payload:, **options)
      response = post("/nodes", payload, **options)

      if response['nodes']
        nodes = Nodes.from_response(response)
      else
        access_token = response # ????
      end

      access_token || nodes
    end

    # Allows you to upload an Ultimate Beneficial Ownership document
    # @param payload [Hash]
    # @see https://docs.synapsefi.com/docs/generate-ubo-form
    # @return API response
    def create_ubo(payload:)
      patch("/ubo", payload)
    end

    # Gets user statement
    # @param page [Integer]
    # @param per_page [Integer]
    # @see https://docs.synapsefi.com/docs/statements-by-user
    # @return API response
    def get_user_statement(**options)
      get("/statements", **options)
    end

    # Request to ship CARD-US
    # @note Deprecated
    # @param node_id [String]
    # @param payload [Hash]
    # @return [Synapse::Node] or [Hash]
    def ship_card_node(node_id:, payload:)
      response = patch("/nodes/#{node_id}?ship=YES", payload)
      Node.from_response(repsonse)
    end

    # Request to ship user debit card [Subnet]
    # @param node_id [String]
    # @param payload [Hash]
    # @param subnet_id [String]
    # @return [Synapse::Node] or [Hash]
    def ship_card(node_id:, payload:, subnet_id:)
      response = patch("/nodes/#{node_id}/subnets/#{subnet_id}/ship", payload)
      Subnet.from_response(response)
    end

    # Resets debit card number, cvv, and expiration date
    # @note Deprecated
    # @see https://docs.synapsefi.com/docs/reset-debit-card
    # @param node_id [String]
    # @return [Synapse::Node] or [Hash]
    def reset_card_node(node_id:)
      response = patch("/nodes/#{node_id}?reset=YES", {})
      Node.from_response(response)
    end

    # Creates a new transaction in the API belonging to the provided node
    # @param node_id [String]
    # @param payload [Hash]
    # @param idempotency_key [String] (optional)
    # @return [Synapse::Transaction]
    def create_transaction(node_id:, payload:, **options)
      response = post("/nodes/#{node_id}/trans", payload, **options)
      Transaction.from_response(response, node_id: node_id)
    end

    # Queries the API for a transaction belonging to the supplied node by transaction id
    # @param node_id [String]
    # @param trans_id [String] id of the transaction to find
    # @return [Synapse::Transaction]
    def get_node_transaction(node_id:, trans_id:)
      response = get("/nodes/#{node_id}/trans/#{trans_id}")
      Transaction.from_response(response, node_id: node_id)
    end

    # Queries the API for all transactions belonging to the supplied node
    # @param node_id [String] node to which the transaction belongs
    # @param page [Integer] (optional) response will default to 1
    # @param per_page [Integer] (optional) response will default to 20
    # @return [Array<Synapse::Transaction>]
    def get_all_node_transaction(node_id:, **options)
      response = get("/nodes/#{node_id}/trans", **options)
      Transactions.from_response(response, node_id: node_id)
    end

    # Verifies microdeposits for a node
    # @param node_id [String]
    # @param payload [Hash]
    def verify_micro_deposit(node_id:, payload:)
      response = patch("/nodes/#{node_id}", payload)
      Node.from_response(response)
    end

    # Reinitiate microdeposits on a node
    # @param node_id [String]
    def reinitiate_micro_deposit(node_id:)
      response = patch("/nodes/#{node_id}?resend_micro=YES", {})
      Node.from_response(response)
    end

    # Update supp_id, nickname, etc. for a node
    # @param node_id [String]
    # @param payload [Hash]
    # @see https://docs.synapsefi.com/docs/update-info
    # @return [Synapse::Node]
    def update_node(node_id:, payload:)
      response = patch "/nodes/#{node_id}", payload
      Node.from_response(response)
    end

    # @param node_id [String]
    def delete_node(node_id:)
      delete("/nodes/#{node_id}")
    end

    # Initiates dummy transactions to a node
    # @param node_id [String]
    # @param is_credit [String]
    # @param foreign_transaction [String]
    # @param subnetid [String]
    # @param type [String]
    # @see https://docs.synapsefi.com/docs/trigger-dummy-transactions
    def dummy_transactions(node_id:, **options)
      get("/nodes/#{node_id}/dummy-tran")
    end

    # Adds comment to the transactions
    # @param node_id [String]
    # @param trans_id [String]
    # @param payload [Hash]
    # @return [Synapse::Transaction]
    def comment_transaction(node_id:, trans_id:, payload:)
      response = patch "/nodes/#{node_id}/trans/#{trans_id}", payload
      Transaction.from_response(response, node_id: node_id)
    end

    # Cancels transaction if it has not already settled
    # @param node_id
    # @param trans_id
    # @return API response [Hash]
    def cancel_transaction(node_id:, trans_id:)
      delete("/nodes/#{node_id}/trans/#{trans_id}")
    end

    # Dispute a transaction for a user
    # @param node_id
    # @param trans_id
    # @see https://docs.synapsefi.com/docs/dispute-card-transaction
    # @return API response [Hash]
    def dispute_card_transactions(node_id:, trans_id:, payload:)
      patch("/nodes/#{node_id}/trans/#{trans_id}/dispute", payload)
    end

    # Creates subnet for a node debit card or act/rt number
    # @param node_id [String]
    # @param payload [Hash]
    # @param idempotency_key [String] (optional)
    # @return [Synapse::Subnet]
    def create_subnet(node_id:, payload:, **options)
      response = post("/nodes/#{node_id}/subnets", payload, **options)
      Subnet.from_response(response)
    end

    # Updates subnet debit card and act/rt number
    # @param node_id [String]
    # @param payload [Hash]
    # @param subnet_id [String]
    # @return [Synapse::Subnet]
    def update_subnet(node_id:, payload:, subnet_id:, **_options)
      response = patch("/nodes/#{node_id}/subnets/#{subnet_id}", payload)
      Subnet.from_response(response)
    end

    # Gets all node subnets
    # @param node_id [String]
    # @param page [Integer]
    # @param per_page [Integer]
    # @see https://docs.synapsefi.com/docs/all-node-subnets
    def get_all_subnets(node_id:, **options)
      response = get("/nodes/#{node_id}/subnets", **options)
      Subnets.from_response(response)
    end

    # Queries a node for a specific subnet by subnet_id
    # @param node_id [String] id of node
    # @param subnet_id [String,void] (optional) id of a subnet to look up
    # @param full_dehydrate [String](optional)
    # @return [Synapse::Subnet]
    def get_subnet(node_id:, subnet_id:, **options)
      response = get("/nodes/#{node_id}/subnets/#{subnet_id}", **options)
      Subnet.from_response(response)
    end

    # This endpoint allows you generate a token to push card to digital wallet.
    # @param node_id [String]
    # @param subnet_id [String]
    # @param payload [Hash]
    # @return API response [Hash]
    def push_subnet_to_wallet(node_id:, subnet_id:, payload:, **options)
      post("/nodes/#{node_id}/subnets/#{subnet_id}/push", payload, **options)
    end

    # Gets statement by node
    # @param page [Integer]
    # @param per_page [Integer]
    # @see https://docs.synapsefi.com/docs/statements-by-user
    # @return API response [Hash]
    def get_node_statements(node_id:, **options)
      get("/nodes/#{node_id}/statements", **options)
    end

    # Gets statement by node on demand
    # @param payload [Hash]
    # @see https://docs.synapsefi.com/reference#generate-node-statements
    # @return API response [Hash]
    def generate_node_statements(node_id:, payload:)
      post "/nodes/#{node_id}/statements", payload
    end

    private

    def oauth_path
      "/oauth/#{user_id}"
    end

    def get(path, **options)
      [options[:page], options[:per_page]].compact.each do |arg|
        raise ArgumentError, "#{arg} must be nil or an Integer >= 1" if arg && (!arg.is_a?(Integer) || arg < 1)
      end

      options[:full_dehydrate] = 'yes' if options[:full_dehydrate] == true
      options[:full_dehydrate] = 'no' if options[:full_dehydrate] == false

      params = VALID_QUERY_PARAMS.map do |p|
        options[p] ? "#{p}=#{options[p]}" : nil
      end.compact

      path += '?' + params.join('&') if params.any?

      with_authentication { client.get(@base_path + path) }
    end

    def post(path, payload, **options)
      with_authentication do
        client.post("#{@base_path}#{path}", payload, **options)
      end
    end

    def patch(path, payload, **opts)
      with_authentication do
        client.patch("#{@base_path}#{path}", payload, **opts)
      end
    end

    def delete(path)
      with_authentication { client.delete("#{@base_path}#{path}") }
    end

    def with_authentication
      yield
    rescue Synapse::Error::Unauthorized
      authenticate
      yield
    end
  end
end
