public with sharing class LookupFieldCleaner implements Queueable, Database.AllowsCallouts {
    public void execute(QueueableContext qc){
        if(!FeatureFlagUtil.isEnabled(FeatureFlagUtil.FEATURE_UNINSTALL_HELPER)){
            return;
        }

        String baseUrl   = URL.getOrgDomainUrl().toExternalForm();
        String apiVer    = 'v57.0';
        String sessionId = UserInfo.getSessionId();

        // Query tooling API for lookup fields that reference Flowdometer__Flow__c or reside on it
        String soql = 'SELECT Id FROM CustomField ' +
                      'WHERE (ReferenceTo = \'' + 'Flowdometer__Flow__c' + '\' ) ' +
                      '   OR (TableEnumOrId = \'' + 'Flowdometer__Flow__c' + '\' AND ReferenceTo != null)';

        HttpRequest req = new HttpRequest();
        req.setEndpoint(baseUrl + '/services/data/' + apiVer + '/tooling/query?q=' + EncodingUtil.urlEncode(soql,'UTF-8'));
        req.setMethod('GET');
        req.setHeader('Authorization','Bearer ' + sessionId);

        HttpResponse resp = new Http().send(req);
        if(resp.getStatusCode() >= 300){
            System.debug(LoggingLevel.ERROR,'LookupFieldCleaner query failed: ' + resp.getBody());
            return;
        }

        Map<String,Object> parsed = (Map<String,Object>) JSON.deserializeUntyped(resp.getBody());
        List<Object> records = (List<Object>) parsed.get('records');

        for(Object rec : records){
            String fieldId = (String) ((Map<String,Object>)rec).get('Id');
            HttpRequest del = new HttpRequest();
            del.setEndpoint(baseUrl + '/services/data/' + apiVer + '/tooling/sobjects/CustomField/' + fieldId + '?forceDelete=true');
            del.setMethod('DELETE');
            del.setHeader('Authorization','Bearer ' + sessionId);
            HttpResponse dresp = new Http().send(del);
            if(dresp.getStatusCode() >= 300){
                System.debug(LoggingLevel.ERROR,'Error deleting field ' + fieldId + ': ' + dresp.getBody());
            }
        }
    }
} 