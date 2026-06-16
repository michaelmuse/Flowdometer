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
| `FlowdometerAuthService` | Session-free `checkConnectionStatus()` — verifies the client_credentials token works against `/limits`; backs the Connection Setup LWC |

### How it works

1. **Install** — ECA deploys with the package. Its global OAuth settings ship with the Client Credentials flow enabled at the publisher level; the subscriber-side policy (enablement + Run-As user) is left for the admin.
2. **Enable (one-time admin step)** — In **Setup → External Client App Manager → Flowdometer ECA → Edit Policies**, the admin checks **Enable Client Credentials Flow** and sets a **Run-As user** (a dedicated integration user is recommended). The package does **not** automate this: using a session id to modify an External Client App via the Metadata/Tooling API is a prohibited Security-Review use case. The Connection Setup LWC guides the admin and auto-detects completion.
3. **Runtime** — Every class that needs API access calls `FlowdometerTokenService.getToken()`, which reads the Protected CMDT, POSTs a `client_credentials` token exchange, and returns a Bearer token.  The token is cached for the duration of the Apex transaction.

No Named Credentials, External Credentials, or EAIP components are used at runtime.
No session IDs are used anywhere — not at runtime and not during setup.

## Permissions

Flowdometer creates lookup fields at runtime when an admin configures a Listener, so
the field-level security for those fields cannot ship in a static (managed) permission
set. The package manages permissions as follows:

| Component | Type | Purpose |
|---|---|---|
| `Flowdometer_User` | Managed permission set | General package access; static FLS that propagates on upgrade |
| `Flowdometer_Dynamic_FLS` | Unmanaged permission set (created at runtime) | FLS for dynamically created lookup fields (both directions) |
| `Flowdometer_Access` | Permission set group | Bundles the two permission sets above — **the single unit you assign to users** |

`FlowdometerPermissionReconciler` runs when an admin opens the Listener setup screen.
It creates and continuously reconciles the unmanaged permission set, the permission
set group, and the dynamic field permissions, and auto-assigns the `Flowdometer_Access`
group to administrators. Assigning the group to other (non-admin) users is a deliberate
admin action.

> The package does **not** assign any permission set automatically at install time.

## Admin Setup Steps

After installation:

1. Open the **Flowdometer** app
2. The Connection Setup screen lists the one-time steps and provides an **Open External
   Client App Manager** button. There, edit the **Flowdometer ECA** policies: enable the
   **Client Credentials Flow** and set a **Run-As user** (a dedicated integration user is
   recommended), then **Save**
3. Return to the Flowdometer tab — it detects the connection automatically (or click
   **Check Connection**) and shows "Connected"
4. Assign the **`Flowdometer_Access`** permission set group to the users who need
   Flowdometer (administrators are assigned automatically when the setup screen first
   loads)
5. Start creating Listeners

## Uninstalling Flowdometer

Flowdometer creates components in your org at runtime — flows it activates, lookup
fields on your tracked objects that reference its `Flow__c` object, and an unmanaged
permission set / permission set group. These must be cleared **before** the managed
package can be uninstalled, otherwise Salesforce blocks the uninstall ("This custom
object is referenced by a relationship field." / "This permission set is assigned to
one or more users.").

To uninstall cleanly:

1. Open the **Flowdometer Uninstall** tab and click **Prepare for Uninstall**. This
   deactivates Flowdometer's flows, removes the dynamic lookup fields it created, and
   clears its permission-set assignments.
2. **Erase the deleted fields.** The lookup fields are deleted to each object's
   *Deleted Fields* list. Salesforce does not permit programmatic permanent deletion of
   fields in production orgs, so you must erase them manually: **Setup → Object Manager
   → [tracked object] → Fields & Relationships → Deleted Fields → Erase** for each
   Flowdometer field.
3. Uninstall the package from **Setup → Installed Packages**.

## Security Review Notes

- **No session IDs anywhere** — all callouts use OAuth Bearer tokens from the ECA client\_credentials flow; the prohibited session-id Metadata API call that previously enabled the ECA has been removed in favor of a documented manual admin step
- **Secrets in Protected CMDT** — `Eca_Secret__mdt` is only readable by managed-package Apex; never logged or exposed
- **Token caching** — transaction-scoped only; no persistent token storage
- **Same-org only** — all endpoints derive from `URL.getOrgDomainUrl()`
- **Admin-controlled ECA enablement** — enabling the Client Credentials Flow and the Run-As user is performed by the subscriber admin in Setup, not automated by the package
- **No blanket permission grants** — nothing is assigned at install; dynamic FLS lives
  on an unmanaged permission set and only administrators are auto-assigned the group
- **Dynamic FLS via native DML** — field permissions are granted with `FieldPermissions`
  DML against the package's own unmanaged permission set; no Metadata API callout

See `SECURITY_REVIEW_NOTES.md` for the full architecture and reviewer disclosures.
