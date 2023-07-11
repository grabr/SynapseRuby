# frozen_string_literal: true

require 'rest-client'
require 'open-uri'
require 'json'

module Synapse
  # Wrapper for HTTP requests using RestClient.
  class HTTPClient
    # @!attribute [rw] base_url
    #   @return [String] the base url of the API (production or sandbox)
    # @!attribute [rw] config
    #   @return [Hash] various settings related to request headers
    # @!attribute [rw] raise_for_202
    #   @return [Boolean] relating to how to handle 202 exception
    attr_accessor :base_url, :config, :raise_for_202

    # @param base_url [String] the base url of the API (production or sandbox)
    # @param client_id [String]
    # @param client_secret [String]
    # @param fingerprint [String]
    # @param ip_address [String]
    # @param raise_for_202 [String]
    # @param logging [Boolean] (optional) logs to stdout when true
    # @param log_to [String] (optional) file path to log to file (logging must be true)
    def initialize(base_url:, client_id:, client_secret:, fingerprint:, ip_address:, raise_for_202: false, **options)
      @raise_for_202 = raise_for_202
      log_to         = options[:log_to] || 'stdout'
      RestClient.log = log_to if options[:logging]
      @logging       = options[:logging]

      @config = {
        client_id: client_id,
        client_secret: client_secret,
        fingerprint: fingerprint,
        ip_address: ip_address,
        oauth_key: ''
      }

      @base_url = base_url
    end

    # Returns headers for HTTP requests.
    # @return [Hash]
    def build_headers(idempotency_key: nil, stream: false, headers: {}, **)
      {
        content_type: :json,
        accept: :json,
        'X-SP-USER' => "#{config[:oauth_key]}|#{config[:fingerprint]}",
        'X-SP-GATEWAY' => "#{config[:client_id]}|#{config[:client_secret]}",
        'X-SP-USER-IP' => config[:ip_address],
        **headers
      }.tap do |h|
        if id_key = (idempotency_key || config[:idempotency_key])
          h['X-SP-IDEMPOTENCY-KEY'] = id_key
        end

        h['Transfer-Encoding'] = 'chunked' if stream
      end
    end

    # Updates current HTPP headers
    # @param fingerprint [String]
    # @param oauth_key [String]
    # @param fingerprint [String]
    # @param client_id [String]
    # @param client_secret [String]
    # @param ip_address [String]
    # @param idemopotency_key [String]
    def update_headers(oauth_key: nil, fingerprint: nil, client_id: nil, client_secret: nil, ip_address: nil, idemopotency_key: nil)
      config[:fingerprint]   = fingerprint if fingerprint
      config[:oauth_key]     = oauth_key if oauth_key
      config[:client_id]     = client_id if client_id
      config[:client_secret] = client_secret if client_secret
      config[:ip_address]    = ip_address if ip_address
      config[:idemopotency_key] = idemopotency_key if idemopotency_key
      nil
    end

    # Send a POST request to the given path with the given payload
    # @param path [String]
    # @param payload [HASH]
    # @param **options payload = idempotency_key [String] (optional) avoid accidentally performing the same operation twice
    # @return [Hash] API response
    # @raise [Synapse::Error] subclass depends on HTTP response
    def post(path, payload, **options)
      run_request(method: :post, path: path, body: payload, **options)
     end

    # Sends a GET request to the given path with the given payload.
    # @param path [String]
    # @return [Hash] API response
    # @raise [Synapse::Error] subclass depends on HTTP response
    def get(path)
      run_request(method: :get, path: path)
    end

    # Sends a DELETE request to the given path
    # @param path [String]
    # @return [Hash] API response
    # @raise [Synapse::Error] subclass depends on HTTP response
    def delete(path)
      run_request(method: :delete, path: path)
    end

    # Sends a PATCH request to the given path with the given payload.
    # @param path [String]
    # @param payload [Hash]
    # @return [Hash] API response
    # @raise [Synapse::Error] subclass depends on HTTP response
    def patch(path, payload, **options)
      run_request(method: :patch, path: path, body: payload, **options)
    end

    def oauthenticate(user_id:)
      refresh_token(user_id: user_id)
    end

    private

    def run_request(method:, path:, body: nil, **options)
      # IO objects will be streamed
      # (via adding the Transfer-Encoding: chunked) header automatically
      if body.respond_to?(:read) && options[:stream] != false
        options[:stream] = true
      elsif body.is_a?(Hash)
        body = body.to_json
      end

      response = with_error_handling do
        RestClient::Request.execute(
          method: method,
          url: full_url(path),
          payload: body,
          headers: build_headers(**options),
          timeout: 300
        )
      end

      json = JSON.parse(response)

      if (raise_for_202 && json['http_code'] == '202') || error?(json)
        raise Error.from_response(json)
      else
        json
      end
    end

    def error?(response)
      response['error'] && !response['error'].empty?
    end

    # get user
    # get refresh_token
    # send refresh_token to oauth path
    # grabs the refresh token and formats a refresh token payload
    def refresh_token(user_id:)
      path = "/users/#{user_id}"
      response = get(path)
      refresh_token = response['refresh_token']

      refresh_token = { 'refresh_token' => refresh_token }
      oauth_path = oauth_path(user_id)
      authenticate(refresh_token, oauth_path)
    end

    # options payload to change scope of oauth
    def authenticate(refresh_token, oauth_path)
      oauth_key = post(oauth_path, refresh_token)
      oauth_key = oauth_key['oauth_key']
      update_headers(oauth_key: oauth_key)
      nil
    end

    def oauth_path(user_id)
      "/oauth/#{user_id}"
    end

    def full_url(path)
      "#{base_url}#{path}"
    end

    # raising an exception based on http_request
    # yeilds if http_request raises an exception
    def with_error_handling
      yield
    rescue RestClient::Exceptions::Timeout
      body = {
        error: {
          en: 'Request Timeout'
        },
        http_code: 504
      }
      raise Error.from_response(body)
    rescue RestClient::Exception => e
      body = if e.response.headers[:content_type] == 'application/json'
        JSON.parse(e.response.body)
      else
        {
          error: {
            en: e.response.body
          },
          http_code: e.response.code
        }
      end
      raise Error.from_response(body)
    end
  end
end
