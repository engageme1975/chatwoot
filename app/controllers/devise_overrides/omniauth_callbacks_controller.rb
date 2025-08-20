class DeviseOverrides::OmniauthCallbacksController < DeviseTokenAuth::OmniauthCallbacksController
  include EmailHelper

  def omniauth_success
    Rails.logger.info '=== OMNIAUTH SUCCESS CALLED ==='
    Rails.logger.info "Params: #{params.inspect}"
    Rails.logger.info "Provider: #{params[:provider]}"
    Rails.logger.info "Code: #{params[:code]}"
    Rails.logger.info "State: #{params[:state]}"

    # Check if we have the omniauth.auth in request environment
    if request.env['omniauth.auth'].present?
      Rails.logger.info "Auth hash found: #{request.env['omniauth.auth']['provider']}"
      get_resource_from_auth_hash
      @resource.present? ? sign_in_user : sign_up_user
    else
      Rails.logger.error 'No omniauth.auth found in request.env'
      Rails.logger.info "Available env keys: #{request.env.keys.grep(/omniauth|devise/)}"

      # Try to manually create auth hash from Keycloak callback
      if params[:code].present? && params[:provider] == 'keycloak'
        Rails.logger.info 'Attempting manual OAuth token exchange...'
        manual_keycloak_auth
      else
        redirect_to login_page_url(error: 'authentication-failed')
      end
    end
  rescue StandardError => e
    Rails.logger.error "Error in omniauth_success: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    redirect_to login_page_url(error: 'authentication-failed')
  end

  def manual_keycloak_auth
    # For now, redirect to error - we'll implement token exchange if needed
    Rails.logger.error 'Manual OAuth not implemented yet'
    redirect_to login_page_url(error: 'oauth-setup-required')
  end

  def keycloak
    omniauth_success
  end

  def redirect_callbacks
    # Handle Keycloak callback directly instead of redirecting
    provider = params[:provider]

    if provider == 'keycloak'
      Rails.logger.info '=== HANDLING KEYCLOAK CALLBACK DIRECTLY ==='
      Rails.logger.info "Params: #{params.inspect}"
      Rails.logger.info "Auth env keys: #{request.env.keys.grep(/omniauth/)}"

      # Check if omniauth.auth is available
      if request.env['omniauth.auth'].present?
        Rails.logger.info 'Auth hash found in redirect_callbacks'
        # Process the authentication
        keycloak
      else
        Rails.logger.error 'No auth hash in redirect_callbacks, manual token exchange needed'
        manual_keycloak_token_exchange
      end
    else
      # For other providers, use the original redirect approach
      redirect_to "/auth/#{provider}/callback?#{request.query_string}", allow_other_host: false
    end
  end

  def manual_keycloak_token_exchange
    Rails.logger.info '=== MANUAL KEYCLOAK TOKEN EXCHANGE ==='

    # Exchange the authorization code for tokens
    require 'net/http'
    require 'uri'
    require 'json'

    begin
      token_endpoint = "#{ENV.fetch('OIDC_ISSUER', nil)}/protocol/openid-connect/token"

      uri = URI(token_endpoint)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(uri)
      request.set_form_data({
                              'grant_type' => 'authorization_code',
                              'client_id' => ENV.fetch('OIDC_CLIENT_ID', nil),
                              'client_secret' => ENV.fetch('OIDC_CLIENT_SECRET', nil),
                              'code' => params[:code],
                              'redirect_uri' => "#{ENV.fetch('FRONTEND_URL', nil)}/omniauth/keycloak/callback"
                            })

      response = http.request(request)

      if response.code == '200'
        token_data = JSON.parse(response.body)
        Rails.logger.info 'Token exchange successful'

        # Get user info
        get_keycloak_user_info(token_data['access_token'])
      else
        Rails.logger.error "Token exchange failed: #{response.code} - #{response.body}"
        redirect_to login_page_url(error: 'token-exchange-failed')
      end
    rescue StandardError => e
      Rails.logger.error "Token exchange error: #{e.message}"
      redirect_to login_page_url(error: 'authentication-failed')
    end
  end

  def get_keycloak_user_info(access_token)
    Rails.logger.info '=== GETTING KEYCLOAK USER INFO ==='

    require 'net/http'
    require 'uri'
    require 'json'

    begin
      userinfo_endpoint = "#{ENV.fetch('OIDC_ISSUER', nil)}/protocol/openid-connect/userinfo"

      uri = URI(userinfo_endpoint)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Get.new(uri)
      request['Authorization'] = "Bearer #{access_token}"

      response = http.request(request)

      if response.code == '200'
        user_info = JSON.parse(response.body)
        Rails.logger.info "User info retrieved: #{user_info.keys}"

        # Create a simplified auth hash structure
        create_auth_hash_and_process(user_info)
      else
        Rails.logger.error "User info request failed: #{response.code} - #{response.body}"
        redirect_to login_page_url(error: 'userinfo-failed')
      end
    rescue StandardError => e
      Rails.logger.error "User info error: #{e.message}"
      redirect_to login_page_url(error: 'authentication-failed')
    end
  end

  def create_auth_hash_and_process(user_info)
    Rails.logger.info '=== CREATING AUTH HASH ==='
    Rails.logger.info "User info: #{user_info}"

    # Create a mock auth hash structure that matches what our controller expects
    @mock_auth_hash = {
      'provider' => 'keycloak',
      'info' => {
        'email' => user_info['email'],
        'name' => user_info['name'] || "#{user_info['given_name']} #{user_info['family_name']}".strip,
        'given_name' => user_info['given_name'],
        'family_name' => user_info['family_name'],
        'image' => user_info['picture']
      },
      'extra' => {
        'raw_info' => user_info
      }
    }

    Rails.logger.info "Created auth hash: #{@mock_auth_hash}"

    # Process the authentication using our mock auth hash
    process_keycloak_authentication
  end

  def process_keycloak_authentication
    Rails.logger.info '=== PROCESSING KEYCLOAK AUTHENTICATION ==='

    # Extract email from our mock auth hash
    email = @mock_auth_hash['info']['email']
    Rails.logger.info "User email: #{email}"

    @resource = User.where(email: email).first

    if @resource.present?
      Rails.logger.info 'Existing user found, signing in'
      sign_in_user
    else
      Rails.logger.info 'New user, checking if signup is allowed'
      if account_signup_allowed? && validate_signup_email_is_business_domain_manual(email)
        create_account_for_user_manual
        token = @resource.send(:set_reset_password_token)
        redirect_to "#{ENV.fetch('FRONTEND_URL', nil)}/app/auth/password/edit?config=default&reset_password_token=#{token}"
      else
        redirect_to login_page_url(error: 'no-account-found')
      end
    end
  end

  private

  def sign_in_user
    @resource.skip_confirmation! if confirmable_enabled?

    # once the resource is found and verified
    # we can just send them to the login page again with the SSO params
    # that will log them in
    encoded_email = ERB::Util.url_encode(@resource.email)
    redirect_to login_page_url(email: encoded_email, sso_auth_token: @resource.generate_sso_auth_token)
  end

  def sign_up_user
    return redirect_to login_page_url(error: 'no-account-found') unless account_signup_allowed?
    return redirect_to login_page_url(error: 'business-account-only') unless validate_signup_email_is_business_domain?

    create_account_for_user
    token = @resource.send(:set_reset_password_token)
    frontend_url = ENV.fetch('FRONTEND_URL', nil)
    redirect_to "#{frontend_url}/app/auth/password/edit?config=default&reset_password_token=#{token}"
  end

  def login_page_url(error: nil, email: nil, sso_auth_token: nil)
    frontend_url = ENV.fetch('FRONTEND_URL', nil)
    params = { email: email, sso_auth_token: sso_auth_token }.compact
    params[:error] = error if error.present?

    "#{frontend_url}/app/login?#{params.to_query}"
  end

  def account_signup_allowed?
    # set it to true by default, this is the behaviour across the app
    GlobalConfigService.load('ENABLE_ACCOUNT_SIGNUP', 'false') != 'false'
  end

  def resource_class(_mapping = nil)
    User
  end

  def auth_hash
    request.env['omniauth.auth']
  end

  def get_resource_from_auth_hash # rubocop:disable Naming/AccessorMethodName
    # Debug logging to see what's in the auth hash
    Rails.logger.info '=== AUTH HASH DEBUG ==='
    Rails.logger.info "omniauth.auth present: #{request.env['omniauth.auth'].present?}"
    Rails.logger.info "omniauth.auth: #{request.env['omniauth.auth'].inspect}"
    Rails.logger.info "request.env keys: #{request.env.keys.grep(/omniauth/)}"

    # find the user with their email instead of UID and token
    # Handle different email field locations for different providers
    if auth_hash.nil?
      Rails.logger.error 'AUTH HASH IS NIL - OAuth authentication failed'
      raise 'Authentication failed: No auth hash available'
    end

    email = case auth_hash['provider']
            when 'keycloak'
              auth_hash['info']['email'] || auth_hash['extra']['raw_info']['email']
            else
              auth_hash['info']['email']
            end

    @resource = resource_class.where(email: email).first
  end

  def validate_signup_email_is_business_domain?
    # return true if the user is a business account, false if it is a blocked domain account
    email = case auth_hash['provider']
            when 'keycloak'
              auth_hash['info']['email'] || auth_hash['extra']['raw_info']['email']
            else
              auth_hash['info']['email']
            end

    Account::SignUpEmailValidationService.new(email).perform
  rescue CustomExceptions::Account::InvalidEmail
    false
  end

  def validate_signup_email_is_business_domain_manual(email)
    Account::SignUpEmailValidationService.new(email).perform
  rescue CustomExceptions::Account::InvalidEmail
    false
  end

  def create_account_for_user
    # Extract user information based on provider
    user_name, user_email, user_image, email_verified = case auth_hash['provider']
                                                        when 'keycloak'
                                                          [
                                                            auth_hash['info']['name'] || "#{auth_hash['info']['given_name']} #{auth_hash['info']['family_name']}".strip,
                                                            auth_hash['info']['email'] || auth_hash['extra']['raw_info']['email'],
                                                            auth_hash['info']['image'],
                                                            auth_hash['extra']['raw_info']['email_verified'] || auth_hash['info']['email_verified'] || false
                                                          ]
                                                        else
                                                          [
                                                            auth_hash['info']['name'],
                                                            auth_hash['info']['email'],
                                                            auth_hash['info']['image'],
                                                            auth_hash['info']['email_verified']
                                                          ]
                                                        end

    # Check for account_id from Keycloak custom attributes
    target_account_id = nil
    if auth_hash['provider'] == 'keycloak'
      # Try different locations where account_id might be stored
      target_account_id = auth_hash['extra']['raw_info']['account_id'] ||
                          auth_hash['extra']['raw_info']['chatwoot_account_id'] ||
                          auth_hash['info']['account_id']
      Rails.logger.info "Keycloak account_id found: #{target_account_id}" if target_account_id
    end

    # Use default account ID 2 if no account_id provided
    target_account_id ||= 2
    Rails.logger.info "Using account_id: #{target_account_id}"

    # Check if target account exists
    target_account = Account.find_by(id: target_account_id)
    unless target_account
      Rails.logger.error "Account with ID #{target_account_id} not found, creating new account"
      target_account_id = nil  # This will trigger AccountBuilder to create new account
    end

    # Generate a strong password for OAuth users (they won't use it directly)
    generated_password = SecureRandom.base64(16) + 'Aa1!'

    if target_account_id && target_account
      # Add user to existing account
      @resource = User.new(
        email: user_email,
        name: user_name,
        password: generated_password,
        confirmed_at: email_verified ? Time.current : nil
      )
      @resource.save!

      # Add user to the target account
      AccountUser.create!(
        account: target_account,
        user: @resource,
        role: :agent  # You can change this to :administrator if needed
      )
      @account = target_account
      Rails.logger.info "Added user to existing account: #{target_account.name} (ID: #{target_account_id})"
    else
      # Create new account (fallback)
      @resource, @account = AccountBuilder.new(
        account_name: extract_domain_without_tld(user_email),
        user_full_name: user_name,
        email: user_email,
        locale: I18n.locale,
        confirmed: email_verified,
        user_password: generated_password
      ).perform
      Rails.logger.info "Created new account: #{@account.name}"
    end

    Avatar::AvatarFromUrlJob.perform_later(@resource, user_image) if user_image.present?
  end

  def create_account_for_user_manual
    # Extract user information from our mock auth hash
    user_name = @mock_auth_hash['info']['name']
    user_email = @mock_auth_hash['info']['email']
    user_image = @mock_auth_hash['info']['image']
    email_verified = @mock_auth_hash['extra']['raw_info']['email_verified'] || false

    # Check for account_id from Keycloak custom attributes
    target_account_id = @mock_auth_hash['extra']['raw_info']['account_id'] ||
                        @mock_auth_hash['extra']['raw_info']['chatwoot_account_id'] ||
                        @mock_auth_hash['info']['account_id']

    # Use default account ID 2 if no account_id provided
    target_account_id ||= 2
    Rails.logger.info "Using account_id: #{target_account_id}"

    # Check if target account exists
    target_account = Account.find_by(id: target_account_id)
    unless target_account
      Rails.logger.error "Account with ID #{target_account_id} not found, creating new account"
      target_account_id = nil  # This will trigger AccountBuilder to create new account
    end

    generated_password = SecureRandom.base64(16) + 'Aa1!'

    if target_account_id && target_account
      # Add user to existing account
      @resource = User.new(
        email: user_email,
        name: user_name,
        password: generated_password,
        confirmed_at: email_verified ? Time.current : nil
      )
      @resource.save!

      # Add user to the target account
      AccountUser.create!(
        account: target_account,
        user: @resource,
        role: :agent  # You can change this to :administrator if needed
      )
      @account = target_account
      Rails.logger.info "Added user to existing account: #{target_account.name} (ID: #{target_account_id})"
    else
      # Create new account (fallback)
      @resource, @account = AccountBuilder.new(
        account_name: extract_domain_without_tld(user_email),
        user_full_name: user_name,
        email: user_email,
        locale: I18n.locale,
        confirmed: email_verified,
        user_password: generated_password
      ).perform
      Rails.logger.info "Created new account: #{@account.name}"
    end

    Avatar::AvatarFromUrlJob.perform_later(@resource, user_image) if user_image.present?
  end

  def default_devise_mapping
    'user'
  end
end
