# Flowdometer

A Salesforce 2GP managed package for monitoring and measuring field-change workflows.

## Authentication Architecture

Flowdometer makes same-org Tooling and Metadata API calls to create lookup fields,
enable history tracking, and manage listener configuration.  All API access uses an
OAuth 2.0 **client\_credentials** flow backed by a packaged External Client App (ECA).

| Component | Purpose |
|---|---|
| `Flowdometer_ECA` (ExternalClientApplication) | Packaged OAuth client; its Consumer Key / Secret replicate to subscriber orgs via ECA "Reference" mechanism |
| `Eca_Secret__mdt` (Protected Custom Metadata) | Stores the client ID and secret; only accessible to managed-package Apex |
| `FlowdometerTokenService` | Exchanges credentials for an access token via `/services/oauth2/token`; caches token per transaction |
| `FlowdometerAuthService` | One-click "Complete Setup" enables Client Credentials + sets Run-As user via Metadata API SOAP call |

### How it works

1. **Install** — ECA deploys with the package. A policy auto-generates with Client Credentials disabled.
2. **Complete Setup** — Admin clicks the button in the Flowdometer app.  `FlowdometerAuthService.completeSetup()` sends a SOAP `updateMetadata` call (via a VF-sourced session) to enable Client Credentials and set the current admin as Run-As user.
3. **Runtime** — Every class that needs API access calls `FlowdometerTokenService.getToken()`, which reads the Protected CMDT, POSTs a `client_credentials` token exchange, and returns a Bearer token.  The token is cached for the duration of the Apex transaction.

No Named Credentials, External Credentials, or EAIP components are used at runtime.
No session IDs are used for ongoing API calls.

## Admin Setup Steps

After installation:

1. Open the **Flowdometer** app
2. The Setup LWC shows "Almost ready!" — click **Complete Setup**
3. Click **Check Connection** — should show "Connected!"
4. Start creating Listeners

## Security Review Notes

- **No `UserInfo.getSessionId()` in runtime API calls** — all callouts use OAuth Bearer tokens from the ECA client\_credentials flow
- **Session ID used once** — only during "Complete Setup" to invoke the Metadata API SOAP endpoint (required because Lightning sessions lack Metadata API scope)
- **Secrets in Protected CMDT** — `Eca_Secret__mdt` is only readable by managed-package Apex; never logged or exposed
- **Token caching** — transaction-scoped only; no persistent token storage
- **Same-org only** — all endpoints derive from `URL.getOrgDomainUrl()`
- **Admin-gated** — setup action requires Customize Application permission
