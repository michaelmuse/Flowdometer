// Test creating a Listener with field history tracking using Session ID

// Simulate what happens when creating a Listener on Opportunity.StageName
String objectApiName = 'Opportunity';
String fieldApiName = 'StageName';

// 1. Enable field history tracking
HttpRequest req = new HttpRequest();
req.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + '/services/data/v58.0/tooling/sobjects/FieldHistoryArchive');
req.setMethod('POST');
req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
req.setHeader('Content-Type', 'application/json');

Map<String, Object> payload = new Map<String, Object>{
    'ParentEntity' => objectApiName,
    'FieldName' => fieldApiName,
    'ArchiveAfterMonths' => 18,
    'ArchiveRetentionYears' => 10
};

req.setBody(JSON.serialize(payload));

Http http = new Http();
HttpResponse res = http.send(req);

System.debug('Field History Response Status: ' + res.getStatusCode());
System.debug('Field History Response Body: ' + res.getBody());

// 2. Test querying to see if it worked
HttpRequest checkReq = new HttpRequest();
String query = 'SELECT Id,  ParentEntity, FieldName FROM FieldHistoryArchive WHERE ParentEntity = \'' + objectApiName + '\'';
checkReq.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + '/services/data/v58.0/tooling/query/?q=' + EncodingUtil.urlEncode(query, 'UTF-8'));
checkReq.setMethod('GET');
checkReq.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());

HttpResponse checkRes = http.send(checkReq);
System.debug('Check Query Status: ' + checkRes.getStatusCode());
System.debug('Check Query Body: ' + checkRes.getBody());
