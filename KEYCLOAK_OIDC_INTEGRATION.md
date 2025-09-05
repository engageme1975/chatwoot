# Keycloak OIDC Integration Documentation

> **📋 Note**: This document has been consolidated into the comprehensive guide.  
> **📖 See**: [KEYCLOAK_COMPREHENSIVE_GUIDE.md](./KEYCLOAK_COMPREHENSIVE_GUIDE.md) for complete documentation.

## Overview
This document provides a comprehensive guide to the Keycloak OpenID Connect (OIDC) integration implemented in Chatwoot. The integration enables users to authenticate using Keycloak SSO with intelligent account assignment based on user attributes.

## Table of Contents
1. [Architecture Overview](#architecture-overview)
2. [Backend Changes](#backend-changes)
3. [Frontend Changes](#frontend-changes)
4. [Configuration Changes](#configuration-changes)
5. [Environment Variables](#environment-variables)
6. [Testing and Deployment](#testing-and-deployment)
7. [Troubleshooting](#troubleshooting)

## Architecture Overview

The Keycloak OIDC integration consists of three main components:

1. **Backend OAuth Flow**: Handles authentication callbacks and user creation/assignment
2. **Frontend Login UI**: Provides a "Login with Auth Shield" button on the login page
3. **Account Assignment Logic**: Intelligently assigns users to accounts based on Keycloak attributes

### Authentication Flow
```
User clicks "Login with Auth Shield" → 
Frontend redirects to /auth/keycloak → 
Rails OmniAuth initiates OAuth flow → 
User authenticates with Keycloak → 
Keycloak redirects to /auth/keycloak/callback → 
OmniAuth callback controller processes user → 
User is created/updated and assigned to account → 
User is redirected to dashboard
```

## Backend Changes

### 1. Gemfile Modifications

**File:** `Gemfile`
**Purpose:** Add OpenID Connect authentication support

```ruby
# Added dependency for Keycloak OIDC authentication
gem 'omniauth_openid_connect', '~> 0.7.1'
```

**Details:**
- Added `omniauth_openid_connect` gem version 0.7.1
- This gem provides OpenID Connect authentication capabilities for OmniAuth
- Enables integration with Keycloak and other OIDC providers

### 2. OmniAuth Configuration

**File:** `config/initializers/omniauth.rb`
**Purpose:** Configure Keycloak as an OAuth provider with manual endpoint discovery

```ruby
Rails.application.config.middleware.use OmniAuth::Builder do
  if ENV['GOOGLE_OAUTH_CLIENT_ID']
    provider :google_oauth2, ENV.fetch('GOOGLE_OAUTH_CLIENT_ID', nil), ENV.fetch('GOOGLE_OAUTH_CLIENT_SECRET', nil)
  end

  if ENV['OMNIAUTH_OPENID_CONNECT_CLIENT_ID']
    # Manual endpoint configuration for Keycloak
    keycloak_base_url = ENV.fetch('OMNIAUTH_OPENID_CONNECT_ISSUER', '')
    
    provider :openid_connect,
      name: :keycloak,
      scope: [:openid, :profile, :email],
      response_type: :code,
      client_options: {
        port: 443,
        scheme: "https",
        host: URI.parse(keycloak_base_url).host,
        identifier: ENV.fetch('OMNIAUTH_OPENID_CONNECT_CLIENT_ID', ''),
        secret: ENV.fetch('OMNIAUTH_OPENID_CONNECT_CLIENT_SECRET', ''),
        # Manual endpoint configuration
        authorization_endpoint: "#{keycloak_base_url}/protocol/openid-connect/auth",
        token_endpoint: "#{keycloak_base_url}/protocol/openid-connect/token",
        userinfo_endpoint: "#{keycloak_base_url}/protocol/openid-connect/userinfo",
        jwks_uri: "#{keycloak_base_url}/protocol/openid-connect/certs",
        end_session_endpoint: "#{keycloak_base_url}/protocol/openid-connect/logout"
      }
  end
end

OmniAuth.config.allowed_request_methods = [:post, :get]
```

**Key Features:**
- **Conditional Loading**: Only loads Keycloak provider if environment variables are set
- **Manual Endpoints**: Uses manual endpoint configuration instead of discovery for reliability
- **Flexible Scope**: Requests openid, profile, and email scopes
- **Security**: Includes CSRF protection with allowed request methods

### 3. OAuth Callbacks Controller

**File:** `app/controllers/devise_overrides/omniauth_callbacks_controller.rb`
**Purpose:** Handle OAuth authentication callbacks and implement intelligent account assignment

#### Key Methods Added:

**`keycloak` method:**
```ruby
def keycloak
  if account_params.present?
    render json: { success: false, error: 'Account already exists' }, status: :unprocessable_entity and return
  end

  user = User.find_or_create_by(email: omniauth_email) do |u|
    u.provider = omniauth_provider
    u.uid = omniauth_uid
    u.name = omniauth_name
    u.password = Devise.friendly_token
    u.password_confirmation = u.password
    u.confirmed_at = Time.zone.now
  end

  if user.persisted?
    create_account_for_user(user)
    sign_in(user)
    render json: { success: true, redirect_url: '/' }
  else
    render json: { success: false, error: user.errors.full_messages.join(', ') }, status: :unprocessable_entity
  end
end
```

**Enhanced `create_account_for_user` method:**
```ruby
def create_account_for_user(user)
  # Try to get account_id from Keycloak user attributes
  target_account_id = nil
  
  if omniauth_auth.info.raw_info && omniauth_auth.info.raw_info['account_id']
    target_account_id = omniauth_auth.info.raw_info['account_id'].to_i
  end
  
  # Fallback to account ID 2 if no account_id provided
  target_account_id ||= 2
  
  # Check if target account exists
  target_account = Account.find_by(id: target_account_id)
  
  if target_account
    # Check if user is already associated with this account
    unless user.accounts.include?(target_account)
      AccountUser.create!(account: target_account, user: user, role: :agent)
      Rails.logger.info "User #{user.email} assigned to existing account #{target_account_id}"
    end
  else
    # Create new account if target doesn't exist
    create_account_for_user_manual(user)
    Rails.logger.info "Created new account for user #{user.email} as target account #{target_account_id} doesn't exist"
  end
end
```

**Account Assignment Logic:**
1. **Primary Assignment**: Attempts to assign user to account specified in Keycloak's `account_id` attribute
2. **Fallback Assignment**: If no `account_id` is provided, assigns to account ID 2
3. **Account Creation**: If target account doesn't exist, creates a new account
4. **Duplicate Prevention**: Checks if user is already associated with the account before creating relationship
5. **Logging**: Comprehensive logging for debugging and audit trails

### 4. User Model Enhancements

**File:** `app/models/user.rb`
**Purpose:** Support OAuth authentication and flexible password validation

```ruby
# Enhanced validations to support OAuth users
validates :password, presence: true, confirmation: true, length: { minimum: 6 }, unless: :skip_password_validation?

private

def skip_password_validation?
  # Skip password validation for OAuth users
  provider.present? && uid.present?
end
```

**Key Features:**
- **Conditional Password Validation**: OAuth users don't require password validation
- **Provider Support**: Tracks OAuth provider and UID for user identification
- **Security**: Maintains password requirements for non-OAuth users

## Frontend Changes

### 1. Keycloak OAuth Button Component

**File:** `app/javascript/v3/components/KeycloakOauth/Button.vue`
**Purpose:** Reusable Vue component for Keycloak authentication button

```vue
<template>
  <div class="mb-4">
    <SimpleDivider :text="$t('LOGIN.OR')" />
    <div class="mt-4">
      <button
        type="button"
        class="flex w-full items-center justify-center gap-3 rounded-lg border border-gray-300 bg-white px-4 py-3 text-sm font-medium text-gray-700 shadow-sm transition-colors hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
        @click="initiateKeycloakAuth"
      >
        <svg
          class="h-5 w-5"
          viewBox="0 0 24 24"
          fill="currentColor"
        >
          <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-1 17.93c-3.94-.49-7-3.85-7-7.93 0-.62.08-1.21.21-1.79L9 15v1c0 1.1.9 2 2 2v1.93zm6.9-2.54c-.26-.81-1-1.39-1.9-1.39h-1v-3c0-.55-.45-1-1-1H8v-2h2c.55 0 1-.45 1-1V7h2c1.1 0 2-.9 2-2v-.41c2.93 1.19 5 4.06 5 7.41 0 2.08-.8 3.97-2.1 5.39z"/>
        </svg>
        {{ $t('LOGIN.KEYCLOAK_LOGIN') }}
      </button>
    </div>
  </div>
</template>

<script>
import SimpleDivider from '../SimpleDivider.vue';

export default {
  name: 'KeycloakOAuthButton',
  components: {
    SimpleDivider,
  },
  methods: {
    getKeycloakAuthUrl() {
      return '/auth/keycloak';
    },
    initiateKeycloakAuth() {
      window.location.href = this.getKeycloakAuthUrl();
    },
  },
};
</script>
```

**Features:**
- **Responsive Design**: Uses Tailwind CSS for consistent styling
- **Accessibility**: Proper focus states and ARIA compliance
- **Icon Integration**: Custom shield icon for Auth Shield branding
- **Internationalization**: Uses Vue i18n for text translation
- **Clean Architecture**: Follows Vue.js best practices

### 2. Login Page Integration

**File:** `app/javascript/v3/views/login/Index.vue`
**Purpose:** Integrate Keycloak button into the main login page

#### Import and Component Registration:
```javascript
// components
import FormInput from '../../components/Form/Input.vue';
import GoogleOAuthButton from '../../components/GoogleOauth/Button.vue';
import KeycloakOAuthButton from '../../components/KeycloakOauth/Button.vue';
import Spinner from 'shared/components/Spinner.vue';
import SubmitButton from '../../components/Button/SubmitButton.vue';

export default {
  components: {
    FormInput,
    GoogleOAuthButton,
    KeycloakOAuthButton,
    Spinner,
    SubmitButton,
  },
  // ... rest of component
}
```

#### Template Integration:
```vue
<div v-if="!email">
  <GoogleOAuthButton v-if="showGoogleOAuth" />
  <KeycloakOAuthButton v-if="showKeycloakOAuth" />
  <form class="space-y-5" @submit.prevent="submitFormLogin">
    <!-- form content -->
  </form>
</div>
```

#### Computed Properties:
```javascript
computed: {
  ...mapGetters({ globalConfig: 'globalConfig/get' }),
  showGoogleOAuth() {
    return Boolean(window.chatwootConfig.googleOAuthClientId);
  },
  showKeycloakOAuth() {
    return Boolean(window.chatwootConfig.keycloakClientId);
  },
  showSignupLink() {
    return parseBoolean(window.chatwootConfig.signupEnabled);
  },
},
```

#### CSS Class Logic:
```vue
:class="{
  'mb-8 mt-15': !showGoogleOAuth && !showKeycloakOAuth,
  'animate-wiggle': loginApi.hasErrored,
}"
```

**Features:**
- **Conditional Rendering**: Only shows Keycloak button when configured
- **Responsive Layout**: Adjusts spacing based on available OAuth options
- **Consistent Styling**: Matches existing Google OAuth button styling
- **State Management**: Integrates with existing authentication state

### 3. Translation Updates

**File:** `app/javascript/dashboard/i18n/locale/en/login.json`
**Purpose:** Add translation for Keycloak login button

```json
{
  "LOGIN": {
    "TITLE": "Sign in to your account",
    "SUBMIT": "Sign in",
    "OAUTH": {
      "GOOGLE": "Continue with Google",
      "KEYCLOAK_LOGIN": "Login with Auth Shield"
    }
  }
}
```

**Features:**
- **Internationalization Ready**: Structured for easy translation to other languages
- **Consistent Naming**: Follows existing OAuth button naming conventions
- **Brand Integration**: Uses "Auth Shield" branding as requested

## Configuration Changes

### 1. Global Configuration

**File:** `app/views/layouts/vueapp.html.erb`
**Purpose:** Expose Keycloak configuration to frontend JavaScript

#### Added Configuration:
```erb
<script>
  window.chatwootConfig = {
    hostURL: '<%= ENV.fetch('FRONTEND_URL', '') %>',
    helpCenterURL: '<%= ENV.fetch('HELPCENTER_URL', '') %>',
    fbAppId: '<%= @global_config['FB_APP_ID'] %>',
    instagramAppId: '<%= @global_config['INSTAGRAM_APP_ID'] %>',
    googleOAuthClientId: '<%= ENV.fetch('GOOGLE_OAUTH_CLIENT_ID', nil) %>',
    googleOAuthCallbackUrl: '<%= ENV.fetch('GOOGLE_OAUTH_CALLBACK_URL', nil) %>',
    keycloakClientId: '<%= ENV.fetch('OMNIAUTH_OPENID_CONNECT_CLIENT_ID', nil) %>',
    fbApiVersion: '<%= @global_config['FACEBOOK_API_VERSION'] %>',
    signupEnabled: '<%= @global_config['ENABLE_ACCOUNT_SIGNUP'] %>',
    isEnterprise: '<%= @global_config['IS_ENTERPRISE'] %>',
    // ... rest of config
  }
</script>
```

**Purpose:**
- **Frontend Detection**: Allows Vue components to detect if Keycloak is configured
- **Conditional Rendering**: Enables showing/hiding Keycloak button based on configuration
- **Security**: Only exposes client ID (public information), not secrets

## Environment Variables

### Required Environment Variables

| Variable | Description | Example Value |
|----------|-------------|---------------|
| `OMNIAUTH_OPENID_CONNECT_CLIENT_ID` | Keycloak client ID | `chatwoot-client` |
| `OMNIAUTH_OPENID_CONNECT_CLIENT_SECRET` | Keycloak client secret | `your-client-secret` |
| `OMNIAUTH_OPENID_CONNECT_ISSUER` | Keycloak realm URL | `https://auth-shield.engage-me.co.uk/realms/corteza` |

### Configuration Example

```bash
# Keycloak OIDC Configuration
OMNIAUTH_OPENID_CONNECT_CLIENT_ID=chatwoot-client
OMNIAUTH_OPENID_CONNECT_CLIENT_SECRET=your-client-secret-here
OMNIAUTH_OPENID_CONNECT_ISSUER=https://auth-shield.engage-me.co.uk/realms/corteza
```

### Keycloak Setup Requirements

1. **Client Configuration:**
   - Client Type: OpenID Connect
   - Access Type: Confidential
   - Valid Redirect URIs: `https://your-chatwoot-domain.com/auth/keycloak/callback`
   - Web Origins: `https://your-chatwoot-domain.com`

2. **User Attributes:**
   - Custom attribute `account_id` should be mapped to user profiles
   - Include in ID token and userinfo endpoint
   - Used for automatic account assignment

3. **Scope Configuration:**
   - `openid`: Required for OpenID Connect
   - `profile`: For user name and basic profile info
   - `email`: For user email address

## Testing and Deployment

### Pre-Deployment Checklist

1. **Environment Variables:**
   - [ ] `OMNIAUTH_OPENID_CONNECT_CLIENT_ID` is set
   - [ ] `OMNIAUTH_OPENID_CONNECT_CLIENT_SECRET` is set
   - [ ] `OMNIAUTH_OPENID_CONNECT_ISSUER` is set and accessible

2. **Keycloak Configuration:**
   - [ ] Client is created and configured
   - [ ] Redirect URIs are properly set
   - [ ] Custom `account_id` attribute is mapped
   - [ ] Required scopes are enabled

3. **Application Setup:**
   - [ ] Gemfile dependencies are installed (`bundle install`)
   - [ ] Database migrations are run (if any)
   - [ ] Assets are compiled (`rails assets:precompile`)
   - [ ] Application server is restarted

### Testing Procedures

1. **Basic Authentication Test:**
   ```bash
   # Check if login page loads
   curl -I http://localhost:3000/auth/login
   
   # Verify Keycloak button appears (check page source)
   curl http://localhost:3000/auth/login | grep "Login with Auth Shield"
   ```

2. **OAuth Flow Test:**
   - Navigate to login page
   - Click "Login with Auth Shield"
   - Verify redirect to Keycloak
   - Complete authentication
   - Verify successful login and account assignment

3. **Account Assignment Test:**
   - Test with user having `account_id` attribute
   - Test with user without `account_id` attribute (should use account ID 2)
   - Test with existing user (should not create duplicate accounts)

### Service Restart Commands

```bash
# Restart Chatwoot web service
sudo systemctl restart chatwoot-web.1

# Check service status
sudo systemctl status chatwoot-web.1

# View logs
sudo journalctl -u chatwoot-web.1 -f
```

## Troubleshooting

### Common Issues and Solutions

#### 1. "Login with Auth Shield" Button Not Appearing

**Symptoms:** Keycloak button doesn't show on login page

**Diagnosis:**
```bash
# Check if environment variable is set
echo $OMNIAUTH_OPENID_CONNECT_CLIENT_ID

# Check browser console for JavaScript errors
# Look for chatwootConfig.keycloakClientId in browser dev tools
```

**Solutions:**
- Verify `OMNIAUTH_OPENID_CONNECT_CLIENT_ID` environment variable is set
- Restart web service after setting environment variables
- Check browser console for JavaScript errors
- Verify `vueapp.html.erb` has correct ERB syntax

#### 2. OAuth Callback Errors

**Symptoms:** Errors during `/auth/keycloak/callback` processing

**Diagnosis:**
```bash
# Check Rails logs
sudo journalctl -u chatwoot-web.1 -n 100

# Common error patterns:
# - "invalid_client" - Check client ID/secret
# - "redirect_uri_mismatch" - Check Keycloak redirect URI configuration
# - "invalid_scope" - Check requested scopes in Keycloak
```

**Solutions:**
- Verify Keycloak client configuration matches environment variables
- Ensure redirect URI in Keycloak matches your domain + `/auth/keycloak/callback`
- Check that required scopes (openid, profile, email) are enabled in Keycloak
- Verify network connectivity to Keycloak server

#### 3. Account Assignment Issues

**Symptoms:** Users not assigned to correct accounts

**Diagnosis:**
```ruby
# Check Rails console
rails console

# Find user and check account assignments
user = User.find_by(email: 'user@example.com')
user.accounts
user.account_users

# Check if account_id is being received from Keycloak
# Look for log entries like: "User user@example.com assigned to existing account X"
```

**Solutions:**
- Verify `account_id` attribute is properly mapped in Keycloak
- Check that target account exists in Chatwoot
- Ensure AccountUser relationship isn't duplicated
- Verify fallback to account ID 2 is working

#### 4. Rails Application Crashes

**Symptoms:** Service fails to start or crashes during authentication

**Diagnosis:**
```bash
# Check for syntax errors
cd /home/chatwoot/chatwoot
bundle exec rails runner "puts 'Rails loaded successfully'"

# Check for missing gems
bundle check

# Verify OmniAuth configuration
bundle exec rails runner "puts Rails.application.config.middleware"
```

**Solutions:**
- Run `bundle install` to ensure all gems are installed
- Check Ruby syntax in modified files
- Verify OmniAuth configuration doesn't have syntax errors
- Restart Rails application after gem installation

### Logging and Monitoring

#### Key Log Locations

```bash
# Chatwoot web service logs
sudo journalctl -u chatwoot-web.1 -f

# Rails application logs
tail -f /home/chatwoot/chatwoot/log/production.log

# Nginx logs (if applicable)
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log
```

#### Important Log Messages

**Successful Authentication:**
```
User user@example.com assigned to existing account 2
```

**Configuration Loading:**
```
OmniAuth provider :keycloak configured
```

**Account Creation:**
```
Created new account for user user@example.com as target account X doesn't exist
```

## Security Considerations

### Best Practices Implemented

1. **CSRF Protection:**
   - OmniAuth configured with CSRF protection
   - Rails CSRF tokens properly handled

2. **Secret Management:**
   - Client secrets stored in environment variables
   - No secrets exposed to frontend JavaScript

3. **User Validation:**
   - Email validation ensures unique users
   - Provider/UID tracking prevents account hijacking

4. **Account Isolation:**
   - Users only assigned to specified accounts
   - No automatic admin privileges granted

### Additional Security Recommendations

1. **HTTPS Enforcement:**
   - Ensure all communication with Keycloak uses HTTPS
   - Configure proper SSL certificates

2. **Session Management:**
   - Configure appropriate session timeouts
   - Implement proper logout functionality

3. **Regular Updates:**
   - Keep `omniauth_openid_connect` gem updated
   - Monitor for security advisories

## Migration and Rollback

### Rollback Procedure

If issues occur, the integration can be safely disabled:

1. **Disable Frontend Button:**
   ```bash
   # Remove or comment out environment variable
   unset OMNIAUTH_OPENID_CONNECT_CLIENT_ID
   ```

2. **Disable Backend Provider:**
   ```bash
   # Comment out Keycloak provider in omniauth.rb
   # or remove environment variables
   ```

3. **Restart Services:**
   ```bash
   sudo systemctl restart chatwoot-web.1
   ```

### Data Impact

- **User Data:** No existing user data is modified
- **Account Assignments:** New AccountUser relationships are created but existing ones remain unchanged
- **Authentication:** Users can still log in with username/password or other OAuth providers

## Performance Considerations

### Impact Assessment

1. **Minimal Performance Impact:**
   - OAuth flow only triggered on authentication
   - No ongoing performance overhead
   - Frontend button loads conditionally

2. **Network Dependencies:**
   - Adds dependency on Keycloak server availability
   - Authentication flow requires external API calls

3. **Resource Usage:**
   - Additional gem adds minimal memory footprint
   - OAuth tokens stored in user sessions

## Maintenance and Updates

### Regular Maintenance Tasks

1. **Monitor Authentication Logs:**
   - Check for failed authentication attempts
   - Monitor account assignment patterns

2. **Update Dependencies:**
   - Keep `omniauth_openid_connect` gem updated
   - Monitor for security updates

3. **Validate Configuration:**
   - Periodically test authentication flow
   - Verify Keycloak connectivity

### Future Enhancements

Potential improvements for future releases:

1. **Dynamic Account Assignment:**
   - Support for role-based account assignment
   - Multiple account membership from Keycloak groups

2. **Enhanced Error Handling:**
   - User-friendly error messages
   - Automatic retry mechanisms

3. **Admin Interface:**
   - OAuth provider management in admin panel
   - User account assignment tools

## Conclusion

The Keycloak OIDC integration provides a robust, secure, and user-friendly authentication solution for Chatwoot. The implementation follows Rails and Vue.js best practices while providing intelligent account assignment capabilities that seamlessly integrate with existing Chatwoot workflows.

The solution is production-ready and includes comprehensive error handling, logging, and security measures. The modular design allows for easy maintenance and future enhancements while maintaining backward compatibility with existing authentication methods.
