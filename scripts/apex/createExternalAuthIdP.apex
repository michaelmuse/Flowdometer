// Create ExternalAuthIdentityProvider via Tooling API

HttpRequest req = new HttpRequest();
req.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + '/services/data/v58.0/tooling/sobjects/ExternalAuthIdentityProvider');
req.setMethod('POST');
req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
req.setHeader('Content-Type', 'application/json');

Map<String, Object> payload = new Map<String, Object>{
    'DeveloperName' => 'Flowdometer_IdP',
    'MasterLabel' => 'Flowdometer IdP',
    'ExternalClientAppId' => 'Flowdometer_ECA'
};

req.setBody(JSON.serialize(payload));

Http http = new Http();
HttpResponse res = http.send(req);

System.debug('Response Status: ' + res.getStatusCode());
System.debug('Response Body: ' + res.getBody());
