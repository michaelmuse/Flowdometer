// Test Tooling API access with Session ID
HttpRequest req = new HttpRequest();
req.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + '/services/data/v58.0/tooling/query/?q=' + EncodingUtil.urlEncode('SELECT Id FROM User LIMIT 1', 'UTF-8'));
req.setMethod('GET');
req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());

Http http = new Http();
HttpResponse res = http.send(req);

System.debug('Status: ' + res.getStatusCode());
System.debug('Body: ' + res.getBody());

// Now test field history tracking enable
if (res.getStatusCode() == 200) {
    // Get Opportunity object ID
    HttpRequest objReq = new HttpRequest();
    objReq.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + '/services/data/v58.0/tooling/query/?q=' + EncodingUtil.urlEncode('SELECT Id FROM EntityDefinition WHERE QualifiedApiName = \'Opportunity\'', 'UTF-8'));
    objReq.setMethod('GET');
    objReq.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
    
    HttpResponse objRes = http.send(objReq);
    System.debug('Entity Query Status: ' + objRes.getStatusCode());
    System.debug('Entity Query Body: ' + objRes.getBody());
}
