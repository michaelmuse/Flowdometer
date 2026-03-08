public with sharing class LookupFieldCleaner implements Queueable, Database.AllowsCallouts {
    private static final String API_VERSION = 'v62.0';

    public void execute(QueueableContext qc){
        if(!FeatureFlagUtil.isEnabled(FeatureFlagUtil.FEATURE_UNINSTALL_HELPER)){
            return;
        }

        FlowdometerTokenService.TokenResult tokenResult = FlowdometerTokenService.getToken();
        if(!tokenResult.success){
            System.debug(LoggingLevel.ERROR, 'LookupFieldCleaner: token acquisition failed – ' + tokenResult.errorMessage);
            return;
        }

        String toolingBase = URL.getOrgDomainUrl().toExternalForm()
            + '/services/data/' + API_VERSION + '/tooling';

        String flowObjectApi = Flow__c.SObjectType.getDescribe().getName();
        String soql = 'SELECT Id FROM CustomField ' +
                      'WHERE (ReferenceTo = \'' + flowObjectApi + '\' ) ' +
                      '   OR (TableEnumOrId = \'' + flowObjectApi + '\' AND ReferenceTo != null)';

        HttpRequest req = new HttpRequest();
        req.setEndpoint(toolingBase + '/query?q=' + EncodingUtil.urlEncode(soql,'UTF-8'));
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + tokenResult.accessToken);

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
            del.setEndpoint(toolingBase + '/sobjects/CustomField/' + fieldId + '?forceDelete=true');
            del.setMethod('DELETE');
            del.setHeader('Authorization', 'Bearer ' + tokenResult.accessToken);
            HttpResponse dresp = new Http().send(del);
            if(dresp.getStatusCode() >= 300){
                System.debug(LoggingLevel.ERROR,'Error deleting field ' + fieldId + ': ' + dresp.getBody());
            }
        }
    }
}