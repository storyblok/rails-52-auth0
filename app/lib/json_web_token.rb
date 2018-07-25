# lib/json_web_token.rb

# frozen_string_literal: true
require 'net/http'
require 'uri'

class JsonWebToken
  def self.verify(token)
    JWT.decode(token, nil,
               true, # Verify the signature of this token
               algorithm: 'RS256',
               iss: 'https://YOUR_AUTH0_TENANT.auth0.com/', ## enter YOUR_AUTH0_TENANT
               verify_iss: true,
               aud: Rails.application.credentials[:auth0][:api_audience], # Different in Rails 5.2
               verify_aud: true) do |header|
      jwks_hash[header['kid']]
    end
  end

  def self.jwks_hash
    jwks_raw = Net::HTTP.get URI("https://YOUR_AUTH0_TENANT.auth0.com/.well-known/jwks.json")  ## enter YOUR_AUTH0_TENANT
    jwks_keys = Array(JSON.parse(jwks_raw)['keys'])
    Hash[
      jwks_keys
      .map do |k|
        [
          k['kid'],
          OpenSSL::X509::Certificate.new(
            Base64.decode64(k['x5c'].first)
          ).public_key
        ]
      end
    ]
  end
end