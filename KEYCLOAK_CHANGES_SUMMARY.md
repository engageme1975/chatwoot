# Keycloak OIDC Integration - File Changes Summary

> **📋 Note**: This document has been consolidated into the comprehensive guide.  
> **📖 See**: [KEYCLOAK_COMPREHENSIVE_GUIDE.md](./KEYCLOAK_COMPREHENSIVE_GUIDE.md) for complete documentation.

## Quick Reference - Files Modified/Created

### 1. Backend Configuration Files

#### `Gemfile`
**Change:** Added omniauth_openid_connect gem dependency
```ruby
# Added for Keycloak OIDC authentication
gem 'omniauth_openid_connect', '~> 0.7.1'
```

#### `config/initializers/omniauth.rb`
**Change:** Created new file with Keycloak OAuth provider configuration
- Configured manual endpoints for Keycloak realm
- Added CSRF protection
- Conditional loading based on environment variables

### 2. Backend Controllers

#### `app/controllers/devise_overrides/omniauth_callbacks_controller.rb`
**Changes Made:**
1. **Added `keycloak` method** for handling Keycloak OAuth callbacks
2. **Enhanced `create_account_for_user` method** with intelligent account assignment:
   - Reads `account_id` from Keycloak user attributes
   - Fallback to account ID 2 if no `account_id` provided
   - Checks for existing account associations
   - Creates AccountUser relationships for existing accounts
3. **Added comprehensive logging** for debugging and audit trails
4. **Added error handling** for account assignment edge cases

**Key Logic Added:**
```ruby
# Extract account_id from Keycloak attributes
target_account_id = nil
if omniauth_auth.info.raw_info && omniauth_auth.info.raw_info['account_id']
  target_account_id = omniauth_auth.info.raw_info['account_id'].to_i
end
target_account_id ||= 2  # Fallback to account ID 2

# Assign to existing account if it exists
target_account = Account.find_by(id: target_account_id)
if target_account && !user.accounts.include?(target_account)
  AccountUser.create!(account: target_account, user: user, role: :agent)
end
```

### 3. Backend Models

#### `app/models/user.rb`
**Change:** Enhanced password validation to support OAuth users
```ruby
# Skip password validation for OAuth users
validates :password, presence: true, confirmation: true, length: { minimum: 6 }, unless: :skip_password_validation?

private

def skip_password_validation?
  provider.present? && uid.present?
end
```

### 4. Frontend Components

#### `app/javascript/v3/components/KeycloakOauth/Button.vue`
**Change:** Created new Vue component for Keycloak authentication button
- **Template:** Auth Shield branded button with SVG icon
- **Styling:** Tailwind CSS classes matching Google OAuth button design
- **Functionality:** Redirects to `/auth/keycloak` endpoint
- **Internationalization:** Uses Vue i18n for button text
- **Dependencies:** Imports SimpleDivider component

**Component Structure:**
```vue
<template>
  <!-- Button with Auth Shield icon and styling -->
</template>

<script>
export default {
  name: 'KeycloakOAuthButton',
  methods: {
    getKeycloakAuthUrl() { return '/auth/keycloak'; },
    initiateKeycloakAuth() { window.location.href = this.getKeycloakAuthUrl(); }
  }
};
</script>
```

#### `app/javascript/v3/views/login/Index.vue`
**Changes Made:**
1. **Added import** for KeycloakOAuthButton component
2. **Registered component** in components object
3. **Added template integration** with conditional rendering
4. **Added computed property** `showKeycloakOAuth()` to detect Keycloak configuration
5. **Updated CSS classes** to handle spacing when both Google and Keycloak buttons are present

**Key Changes:**
```javascript
// Added import
import KeycloakOAuthButton from '../../components/KeycloakOauth/Button.vue';

// Added to components
components: {
  KeycloakOAuthButton,
  // ... other components
},

// Added computed property
showKeycloakOAuth() {
  return Boolean(window.chatwootConfig.keycloakClientId);
},

// Updated template
<KeycloakOAuthButton v-if="showKeycloakOAuth" />

// Updated CSS classes
'mb-8 mt-15': !showGoogleOAuth && !showKeycloakOAuth,
```

### 5. Translation Files

#### `app/javascript/dashboard/i18n/locale/en/login.json`
**Change:** Added translation key for Keycloak login button
```json
{
  "LOGIN": {
    "OAUTH": {
      "GOOGLE": "Continue with Google",
      "KEYCLOAK_LOGIN": "Login with Auth Shield"
    }
  }
}
```

### 6. Configuration Templates

#### `app/views/layouts/vueapp.html.erb`
**Change:** Added Keycloak client ID to global JavaScript configuration
```erb
window.chatwootConfig = {
  // ... existing config
  keycloakClientId: '<%= ENV.fetch('OMNIAUTH_OPENID_CONNECT_CLIENT_ID', nil) %>',
  // ... rest of config
}
```

## Environment Variables Required

| Variable | Purpose | Example |
|----------|---------|---------|
| `OMNIAUTH_OPENID_CONNECT_CLIENT_ID` | Keycloak client identifier | `chatwoot-client` |
| `OMNIAUTH_OPENID_CONNECT_CLIENT_SECRET` | Keycloak client secret | `your-secret-key` |
| `OMNIAUTH_OPENID_CONNECT_ISSUER` | Keycloak realm URL | `https://auth-shield.engage-me.co.uk/realms/corteza` |

## Git Changes Summary

```bash
# Files added:
config/initializers/omniauth.rb
app/javascript/v3/components/KeycloakOauth/Button.vue
KEYCLOAK_OIDC_INTEGRATION.md
KEYCLOAK_CHANGES_SUMMARY.md

# Files modified:
Gemfile
app/controllers/devise_overrides/omniauth_callbacks_controller.rb
app/models/user.rb
app/javascript/v3/views/login/Index.vue
app/javascript/dashboard/i18n/locale/en/login.json
app/views/layouts/vueapp.html.erb
```

## Architecture Flow

```
Login Page (Index.vue)
├── Shows "Login with Auth Shield" button if keycloakClientId is configured
└── Button clicks redirect to /auth/keycloak

OAuth Flow (/auth/keycloak)
├── OmniAuth::Builder initiates OAuth flow with Keycloak
├── User authenticates on Keycloak server
└── Callback returns to /auth/keycloak/callback

Callback Processing (omniauth_callbacks_controller.rb)
├── Creates or finds user by email
├── Extracts account_id from Keycloak user attributes
├── Assigns user to specified account (or account ID 2 as fallback)
├── Creates AccountUser relationship if needed
└── Logs in user and redirects to dashboard
```

## Key Features Implemented

1. **Intelligent Account Assignment:** Users automatically assigned based on Keycloak `account_id` attribute
2. **Fallback Logic:** Default assignment to account ID 2 when no `account_id` provided
3. **Existing User Support:** Handles existing users without creating duplicates
4. **Conditional UI:** Login button only appears when Keycloak is configured
5. **Brand Integration:** "Auth Shield" branding as requested
6. **Security:** Proper CSRF protection and secret management
7. **Error Handling:** Comprehensive error handling and logging
8. **Backward Compatibility:** Doesn't interfere with existing authentication methods

## Testing Commands

```bash
# Restart service after changes
sudo systemctl restart chatwoot-web.1

# Check service status
sudo systemctl status chatwoot-web.1

# View logs
sudo journalctl -u chatwoot-web.1 -f

# Test login page
curl http://localhost:3000/auth/login | grep "Login with Auth Shield"
```

This integration provides a complete, production-ready Keycloak OIDC authentication solution with intelligent account assignment capabilities.
