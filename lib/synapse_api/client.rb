# frozen_string_literal: true

require 'synapse_fi'

module Synapse
  # Initializes various wrapper settings such as development mode and request
  # header values
  class Client
    VALID_QUERY_PARAMS = %i[filter query page per_page full_dehydrate radius zip lat lon limit currency ticker_symbol].freeze

    attr_accessor :http_client
    attr_reader :client_id

    # Alias for #http_client
    alias client http_client

    # @param client_id [String] should be stored in environment variable
    # @param client_secret [String] should be stored in environment variable
    # @param ip_address [String] user's IP address
    # @param fingerprint [String] a hashed value, either unique to user or static
    # @param development_mode [String] default true
    # @param raise_for_202 [Boolean]
    # @param logging [Boolean] (optional) logs to stdout when true
    # @param log_to [String] (optional) file path to log to file (logging must be true)
    def initialize(client_id:, client_secret:, ip_address:, fingerprint: nil, development_mode: true, raise_for_202: nil, **options)
      base_url = if development_mode
                   'https://uat-api.synapsefi.com/v3.1'
                 else
                   'https://api.synapsefi.com/v3.1'
                 end

      @client_id = client_id
      @client_secret = client_secret
      @http_client = HTTPClient.new(base_url: base_url,
                                    client_id: client_id,
                                    client_secret: client_secret,
                                    fingerprint: fingerprint,
                                    ip_address: ip_address,
                                    raise_for_202: raise_for_202,
                                    **options)
    end

    # Queries Synapse API to create a new user
    # @param payload [Hash]
    # @param idempotency_key [String] (optional)
    # @param ip_address [String] (optional)
    # @param fingerprint [String] (optional)
    # @return [Synapse::User]
    # @see https://docs.synapsepay.com/docs/create-a-user payload structure
    def create_user(payload:, ip_address:, **options)
      client.update_headers(ip_address: ip_address, fingerprint: options[:fingerprint])

      response = client.post('/users', payload, **options)
      User.from_response(response, client: client, **options)
    end

    # Queries Synapse API for a user by user_id
    # @param user_id [String] id of the user to find
    # @param full_dehydrate [String] (optional) if true, returns all KYC on user
    # @param ip_address [String] (optional)
    # @param fingerprint [String] (optional)
    # @see https://docs.synapsefi.com/docs/get-user
    # @return [Synapse::User]
    def get_user(user_id:, **options)
      raise ArgumentError, 'client must be a Synapse::Client' unless is_a?(Client)
      raise ArgumentError, 'user_id must be a String' unless user_id.is_a?(String)

      client.update_headers(ip_address: options[:ip_address], fingerprint: options[:fingerprint])

      response = get("/users/#{user_id}", **options)
      User.from_response(response, client: client, **options)
    end

    # Queries Synapse API for platform users
    # @param query [String] (optional) response will be filtered to
    # users with matching name/email
    # @param page [Integer] (optional) response will default to 1
    # @param per_page [Integer] (optional) response will default to 20
    # @return [Array<Synapse::Users>]
    def get_users(**options)
      response = get('/users', **options)
      Users.from_response(response, client: client, **options)
    end

    # Queries Synapse for all transactions on platform
    # @param page [Integer] (optional) response will default to 1
    # @param per_page [Integer] (optional) response will default to 20
    # @return [Array<Synapse::Transactions>]
    def get_all_transaction(**options)
      response = get('/trans', **options)
      Transactions.from_response(response)
    end

    # Queries Synapse API for all nodes belonging to platform
    # @param page [Integer] (optional) response will default to 1
    # @param per_page [Integer] (optional) response will default to 20
    # @return [Array<Synapse::Nodes>]
    def get_all_nodes(**options)
      response = get('/nodes', **options)
      Nodes.from_response(response)
    end

    # Queries Synapse API for all institutions available for bank logins
    # @param page [Integer] (optional) response will default to 1
    # @param per_page [Integer] (optional) response will default to 20
    # @return API response [Hash]
    def get_all_institutions(**options)
      get('/institutions', **options)
    end

    # Queries Synapse API to create a webhook subscriptions for platform
    # @param scope [Hash]
    # @param idempotency_key [String] (optional)
    # @see https://docs.synapsefi.com/docs/create-subscription
    # @return [Synapse::Subscription]
    def create_subscriptions(scope:, **options)
      response = client.post('/subscriptions', scope, **options)
      Subscription.from_response(response)
    end

    # Queries Synapse API for all platform subscriptions
    # @param page [Integer] (optional) response will default to 1
    # @param per_page [Integer] (optional) response will default to 20
    # @return [Array<Synapse::Subscriptions>]
    def get_all_subscriptions(**options)
      response = get('/subscriptions', **options)
      Subscriptions.from_response(response)
    end

    # Queries Synapse API for a subscription by subscription_id
    # @param subscription_id [String]
    # @return [Synapse::Subscription]
    def get_subscription(subscription_id:)
      response = get("/subscriptions/#{subscription_id}")
      Subscription.from_response(response)
    end

    # Updates subscription platform subscription
    # @param subscription_id [String]
    # @param body [Hash]
    # see https://docs.synapsefi.com/docs/update-subscription
    # @return [Synapse::Subscription]
    def update_subscriptions(subscription_id:, body:)
      response = client.patch("/subscriptions/#{subscription_id}", **body)
      Subscription.from_response(response)
    end

    # Returns all of the webhooks belonging to client
    # @param page [Integer] (Optional)
    # @param per_page [Integer] (Optional)
    # @return [Hash]
    def webhook_logs(**options)
      get('/subscriptions/logs', **options)
    end

    # Issues public key for client
    # @param scope [String]
    # @param user_id [String] (Optional)
    # @see https://docs.synapsefi.com/docs/issuing-public-key
    # @note valid scope "OAUTH|POST,USERS|POST,USERS|GET,USER|GET,USER|PATCH,SUBSCRIPTIONS|GET,SUBSCRIPTIONS|POST,SUBSCRIPTION|GET,SUBSCRIPTION|PATCH,CLIENT|REPORTS,CLIENT|CONTROLS"
    def issue_public_key(scope:, user_id: nil)
      path = '/client?issue_public_key=YES'
      path += "&scope=#{scope}"
      path += "&user_id=#{user_id}" if user_id

      response = client.get(path)
      response['public_key_obj']
    end

    # Queries Synapse API for ATMS nearby
    # @param zip [String]
    # @param radius [String]
    # @param lat [String]
    # @param lon [String]
    # @see https://docs.synapsefi.com/docs/locate-atms
    # @return [Hash]
    def locate_atm(**options)
      get('/nodes/atms', **options)
    end

    # Queries Synapse API for Crypto Currencies Quotes
    # @return API response [Hash]
    def get_crypto_quotes
      get('/nodes/crypto-quotes', **options)
    end

    # Queries Synapse API for Crypto Currencies Market data
    # @param limit [Integer]
    # @param currency [String]
    # @return API response [Hash]
    def get_crypto_market_data(**options)
      get('/nodes/crypto-market-watch', **options)
    end

    # Queries Synapse API for Trade Market data
    # @param ticker_symbol [String]
    # @return API response [Hash]
    def get_trade_market_data(**options)
      get('/nodes/trade-market-watch', **options)
    end

    # Queries Synapse API for Routing Verification
    # @param payload [Hash]
    # @return API response [Hash]
    def routing_number_verification(payload:)
      client.post('/routing-number-verification', payload)
    end

    # Queries Synapse API for Address Verification
    # @param payload [Hash]
    # @return API response [Hash]
    def address_verification(payload:)
      client.post('/address-verification', payload)
    end

    private

    def get(path, **options)
      [options[:page], options[:per_page]].compact.each do |arg|
        if arg && (!arg.is_a?(Integer) || arg < 1)
          raise ArgumentError, "#{arg} must be nil or an Integer >= 1"
        end
      end

      params = VALID_QUERY_PARAMS.map do |p|
        options[p] ? "#{p}=#{options[p]}" : nil
      end.compact

      path += '?' + params.join('&') if params.any?

      client.get(path)
    end
  end
end
