public with sharing class FlowDeactivator implements Queueable, Database.AllowsCallouts {
    private Set<String> apiNames;
    public FlowDeactivator(Set<String> apiNames){
        this.apiNames = apiNames;
    }

    public void execute(QueueableContext qc){
        // Feature flag guard – allows turning off from custom metadata
        if(!FeatureFlagUtil.isEnabled(FeatureFlagUtil.FEATURE_UNINSTALL_HELPER)){
            return;
        }

        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        String apiVersion = 'v57.0'; // keep in sync with package API version
        String sessionId = UserInfo.getSessionId();

        for(String apiName : apiNames){
            try{
                // Query Tooling API for active FlowVersion Id
                String soql = 'SELECT ActiveVersionId FROM FlowDefinition WHERE DeveloperName = \'' + apiName + '\'';
                HttpRequest q = new HttpRequest();
                q.setEndpoint(baseUrl + '/services/data/' + apiVersion + '/tooling/query?q=' + EncodingUtil.urlEncode(soql,'UTF-8'));
                q.setMethod('GET');
                q.setHeader('Authorization','Bearer ' + sessionId);

                HttpResponse qResp = new Http().send(q);
                if(qResp.getStatusCode() >= 300){
                    System.debug(LoggingLevel.ERROR,'FlowDeactivator query error for ' + apiName + ': ' + qResp.getBody());
                    continue;
                }

                Map<String,Object> parsed = (Map<String,Object>) JSON.deserializeUntyped(qResp.getBody());
                List<Object> recs = (List<Object>) parsed.get('records');
                if(recs.isEmpty()){
                    continue; // definition not found
                }

                String flowId = (String) ((Map<String,Object>) recs[0]).get('ActiveVersionId');
                if(flowId == null){
                    continue; // already inactive
                }

                // Build Tooling API PATCH request to set status = Obsolete
                HttpRequest req = new HttpRequest();
                req.setEndpoint(baseUrl + '/services/data/' + apiVersion + '/tooling/sobjects/Flow/' + flowId);
                req.setMethod('PATCH');
                req.setHeader('Authorization', 'Bearer ' + sessionId);
                req.setHeader('Content-Type', 'application/json');
                req.setBody('{"Status":"Obsolete"}');

                HttpResponse resp = new Http().send(req);
                if(resp.getStatusCode() >= 300){
                    System.debug(LoggingLevel.ERROR, 'Error deactivating flow ' + apiName + ': ' + resp.getBody());
                }
            }catch(Exception ex){
                System.debug(LoggingLevel.ERROR, 'Exception deactivating flow ' + apiName + ': ' + ex.getMessage());
            }
        }
    }
} 