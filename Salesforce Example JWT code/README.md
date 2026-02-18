# jwtauth - v1.0
This is an example repo to demonstrate JWT Bearer Flow authentication in a managed package.

**Note: This example is focusing only on how to setup JWT. Best practices for storing credentials and certificates  should still be observed. The global Apex classes should not be exposing the resuting session id.** 

## Create self-signed cert and private key

Following https://www.apexhours.com/salesforce-oauth-2-0-jwt-bearer-flow/, on your local system generate an RSA private key

```
openssl genrsa -aes128 -passout pass:x -out server.pass.key 4096
```

create a key file

```
openssl rsa -passin pass:x -in server.pass.key -out server.key
```

request and generate a certificate signing request

```
openssl req -new -key server.key -out server.csr
```

generate the certificate

```
openssl x509 -req -sha256 -days 365 -in server.csr -signkey server.key -out server.crt
```

The two files you need are the certificate (which is public) `server.crt` and the private key `server.key` which *must be kept secret*

## Add remote site setting:

*Note: These are included in the repo.*

https://login.salesforce.com/services/oauth2/token

For a sandbox and scratch org this should be
https://test.salesforce.com/services/oauth2/token

## Connected app in your packaging org

### Configure existing connected App

Update [`JWTAuthAccess.connectedApp-meta.xml`](/force-app/main/default/connectedApps/JWTAuthAccess.connectedApp-meta.xml) with the cerificate content from `server.crt`, excluding the leading `-----BEGIN CERTIFICATE-----` and trailing `-----END CERTIFICATE-----`.

After pushing to the org you will need the resulting `consumerKey` to update [`OAuthController.cls`](/force-app/main/default/classes/OAuthController.cls)

**Note: As a best practice the certificate contents should be excluded from source control metadata.** 
As an alternative, it can be injected via a CLI step - https://github.com/forcedotcom/cli/blob/main/releasenotes/sfdx/README.md#71761-nov-10-2022 

### Alternative - Manual Steps to create connected App

*Note: This step is only required if you aren't using the existing connected app from the repo.*

In your packaging org, create the app as per https://www.apexhours.com/salesforce-oauth-2-0-jwt-bearer-flow/ step 2, you will use option Option 2 and have the admin approve the app when they install your package. You can enable it now for testing, but the installation process will not honor the isAdminApproved setting.

Go to Setup -> Search for `App Manager` -> then click on `New Connected App`. Then provide below details.

1. Fill Name and Email
2. Click on “Enable OAuth Setting“
3. Call back URL “http://localhost/OauthRedirect”
4. Click on “Use Digital Signature” and upload the `server.crt` file.
5. Select the OAuth Scopes needed 
    * Manage user data via APIs (api)
    * Perform requests at any time (refresh_token, offline_access)
7. Click on Save


## Pre-approve profile/permissionset for using the connected app

*Note: The JWTAuthAccess connected app is already included in the repo.*

1. Go to Setup -> click on Manage Apps -> Connected Apps
2. Click ‘Edit’ against your app
3. Click on Permitted Users and select “Admin approved users are pre-authorized“
4. Save.
5. Configure either the Profile or Permission set for the user against the connected app. For testing this will require adding the user to the JWT permission set.

## Set your private key to a protected custom metadata 

### Configure existing protected custom metadata type value

Update [`jwtAuthKey.jwtAuthKey.md-meta.xml`](/force-app/main/default/customMetadata/jwtAuthKey.jwtAuthKey.md-meta.xml) in `<value xsi:type="xsd:string">` with the private key value from `server.key`, excluding the leading `-----BEGIN RSA PRIVATE KEY-----` and trailing `-----END RSA PRIVATE KEY-----`. Ensure there is no embeded whitespace, such as indentation via tabs.

### Alternative - Manual Steps

*Note: This step is only required if you aren't using the provided custom metadata type.*

Go to Setup --> Search for `Custom Metadata Types` -> select 'New Custom Metadata Type'

1. Assign a label: jwtAuthKey
2. Visibility: Only Apex code in the same managed package can see the type. The name of the type and the record are visible if they're referenced in a formula.

Click 'Save'

Create a custom field with the key value of type `Text Area (Long)`
```
Field label: 'value'
Length: 3500
```

accept the auto-created layout, then save.


Select `Manage jwtAuthKeys`, then `new`
```
Label: `jwtAuthKey`
Name: `jwtAuthKey`
Value: copy the ascii armored private key, stripping out the lines "-----BEGIN RSA PRIVATE KEY-----" and "-----END RSA PRIVATE KEY-----"
```
Click `save`

## Set app ID
In [`OAuthController.cls`](/force-app/main/default/classes/OAuthController.cls), set the consumer key to be the consumer key of your app (this value is not secret)

## Deploy the apex classes and demo VF page in this repo
You can use `force:source:push` or `force:source:deploy`, VSCode or your favorite editor. 
Note that the connected app and custom metadata definitions are included here, but need to be updated as above. 

## Deploy package
Do not forget to package the connected app!

Components:
 * classes
    - OAuthController (Ensure the consumerKey has been updated to reflect the deployed connected apps value)
    - OAuthControllerTest
    - JWTRaw
    - JWTRawTest
 * remoteSiteSettings
     - JwtAuth
     - JwtAuthTest
 * customMetadata
     - jwtAuthKey
     - jwtAuthKey - value
 * jwtAuthKey
     - jwtAuthKey (The Custom Metadata Type value with the private key - updated with certificate private key)
  * connectedApps
     - JWTAuthAccess
 * pages
     - OAuthPage (Optional Visualforce page to call the Controller directly)

The JWT permission set can be packaged. However, it can't be used against the connected app when it is deployed to the subcriber org.

## Instructions for subscribers

For the installed JWTAuthAccess connected app:
1. Change the Permitted Users from "All users may self-authorize" to "Admin approved users are pre-authorized"
2. Grant access to the required users via either the Profiles or Permission Sets

## Demo

### Anonymous Apex to invoke the REST API

// The class name will need to be prefixed with the managed package namespace.

```
OAuthController oc = new OAuthController();
string sid = oc.getToken();
Assert.isNotNull(sid);
Assert.isTrue(sid.startsWith(UserInfo.getOrganizationId().substring(0, 15)));

HttpRequest request = new HttpRequest();
request.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + '/services/data/v55.0/limits/');
request.setMethod('GET');
request.setHeader('Authorization', 'Bearer ' + sid);

HttpResponse response = new Http().send(request);
Assert.areEqual(200, response.getStatusCode());
System.debug(response.getBody());
```

### Visualforce page

The page [`OAuthPage.page`](/force-app/main/default/pages/OAuthPage.page) will return the session id from the package.