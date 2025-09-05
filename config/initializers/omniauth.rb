# Explicitly require the OpenID Connect strategy
require 'omniauth_openid_connect'

Rails.application.config.middleware.use OmniAuth::Builder do
  if ENV['GOOGLE_OAUTH_CLIENT_ID'].present?
    provider :google_oauth2, ENV.fetch('GOOGLE_OAUTH_CLIENT_ID', nil), ENV.fetch('GOOGLE_OAUTH_CLIENT_SECRET', nil), {
      provider_ignores_state: true
    }
  end

  # Keycloak OIDC provider
  if ENV['ENABLE_OMNIAUTH'] == 'true' && ENV['OIDC_CLIENT_ID'].present?
    # Parse scope from environment variable (comma-separated string to array)
    scope_array = ENV.fetch('OIDC_SCOPE', 'openid,email,profile').split(',').map(&:strip).map(&:to_sym)

    provider_config = {
      name: :keycloak,
      scope: scope_array,
      response_type: :code,
      issuer: ENV.fetch('OIDC_ISSUER', nil),
      discovery: ENV.fetch('OIDC_PROVIDER_DISCOVERY', 'false') == 'true',
      uid_field: ENV.fetch('OIDC_UID_FIELD', 'sub'),
      client_options: {
        identifier: ENV.fetch('OIDC_CLIENT_ID', nil),
        secret: ENV.fetch('OIDC_CLIENT_SECRET', nil),
        redirect_uri: "#{ENV.fetch('FRONTEND_URL', nil)}/omniauth/keycloak/callback"
      }
    }

    # Add manual endpoints only if discovery is disabled
    unless provider_config[:discovery]
      provider_config[:client_options].merge!({
                                                authorization_endpoint: "#{ENV.fetch('OIDC_ISSUER', nil)}/protocol/openid-connect/auth",
                                                token_endpoint: "#{ENV.fetch('OIDC_ISSUER', nil)}/protocol/openid-connect/token",
                                                userinfo_endpoint: "#{ENV.fetch('OIDC_ISSUER', nil)}/protocol/openid-connect/userinfo",
                                                jwks_uri: "#{ENV.fetch('OIDC_ISSUER', nil)}/protocol/openid-connect/certs"
                                              })
    end

    provider :openid_connect, provider_config
  end
end

# Configure CSRF protection for OmniAuth
OmniAuth.config.allowed_request_methods = [:post, :get]
OmniAuth.config.silence_get_warning = true
