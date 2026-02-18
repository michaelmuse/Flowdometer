# Flowdometer OAuth Migration Guide

## Summary

This document outlines the changes made to Flowdometer's authentication mechanism to comply with Salesforce Security Review requirements. The app previously used `UserInfo.getSessionId()` for same-org Tooling API calls, which was rejected. This update replaces that approach with a platform-managed OAuth flow using Named Credentials and External Credentials.

## Changes Made

### 1. Authentication Replacement

**Old Approach**: Used `UserInfo.getSessionId()` in `FlowdometerAuthService` to make Tooling/Metadata API calls.

**New Approach**: 
- **External Credential**: `Flowdometer_SF_Platform` (uses Salesforce Platform provider with `NamedPrincipal`)
- **Named Credential**: `Flowdometer_API` (binds to the External Credential, uses placeholder URL)
- **Authorization**: Admins authorize once via Setup UI; tokens are managed by Salesforce platform
- **Execution**: All Tooling/Metadata calls use `callout:Flowdometer_API/...` syntax

### 2. FlowdometerAuthService Updates

- Removed all session ID and OAuth 2.0 flow code
- Added new methods:
  - `checkConnectionStatus()` - Tests connection to limits endpoint
  - `getOrgDomainUrl()` - Returns subscriber's My Domain
  - `getNamedCredentialSetupUrl()` - Returns deep link to edit NC
  - `getExternalCredentialAuthUrl()` - Returns deep link to EC authorize page
- Now acts as a connection checker and setup assistant

### 3. Setup LWC Enhancement

- `flowdometerAuthSetup` now provides a clean, admin-friendly UI
- Displays connection status and My Domain
- Provides "Authorize", "Edit Named Credential", and "Validate" buttons
- Fires `authsuccess` event when connected

### 4. Permission Set Update

- Added `externalCredentialPrincipalAccesses` for `Flowdometer_SF_Platform` (NamedPrincipal)
- Added class access for `FlowdometerAuthService`

### 5. Package Manifest Changes

- Removed `OAuthTokenUtil` from Apex classes
- Removed ECA artifacts (`Flowdometer_ECA`, `Flowdometer_ECA_oauth`)
- Updated `ExternalCredential` to `Flowdometer_SF_Platform`
- Kept `NamedCredential` as `Flowdometer_API`

## Admin Setup Steps

After installation:

1. Navigate to the Flowdometer Setup component (e.g., via SetupListenersandGoals app)
2. If not connected, click "Authorize Flowdometer"
3. In the External Credentials setup page, select "Flowdometer SF Platform"
4. Click "Authenticate"
5. Return to the Flowdometer Setup card
6. Click "Validate Connection" to confirm setup
7. The card should now show "Connected"

Note: The "Edit Named Credential" button helps admins update the NC URL to their My Domain if needed.

## Security Review Notes

### Why This Change Was Necessary

- **Session ID Usage**: Previously used `UserInfo.getSessionId()` which is prohibited for Security Review
- **Platform OAuth**: Uses built-in Salesforce OAuth 2.0 with Named Credentials, which is the recommended approach for same-org API access
- **No Token Storage**: Tokens are managed by Salesforce platform, not stored in Apex
- **Least Privilege**: Uses `NamedPrincipal` for org-wide authorization; admin-only setup required
- **No Manual Token Handling**: No Apex code manually handles tokens, refreshes, or secrets

### Compliance Benefits

- **No Session ID Exposure**: Eliminates risk of session token leakage
- **Platform-Managed**: Tokens are refreshed and rotated by Salesforce
- **Audit Trail**: Calls are audited against the authorized principal (admin who authorized)
- **No Secrets**: No private keys, tokens, or credentials stored in code or metadata
- **Same Org Only**: All calls remain within subscriber's org
