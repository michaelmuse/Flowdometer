public with sharing class FlowDeactivator implements Queueable, Database.AllowsCallouts {
    private static final String API_VERSION = 'v62.0';

    private Set<String> apiNames;
    public FlowDeactivator(Set<String> apiNames){
        this.apiNames = apiNames;
    }

    public void execute(QueueableContext qc){
        if(!FeatureFlagUtil.isEnabled(FeatureFlagUtil.FEATURE_UNINSTALL_HELPER)){
            return;
        }

        FlowdometerTokenService.TokenResult tokenResult = FlowdometerTokenService.getToken();
        if(!tokenResult.success){
            System.debug(LoggingLevel.ERROR, 'FlowDeactivator: token acquisition failed – ' + tokenResult.errorMessage);
            return;
        }

        String toolingBase = URL.getOrgDomainUrl().toExternalForm()
            + '/services/data/' + API_VERSION + '/tooling';

        for(String apiName : apiNames){
            try{
                String soql = 'SELECT ActiveVersionId FROM FlowDefinition WHERE DeveloperName = \'' + apiName + '\'';
                HttpRequest q = new HttpRequest();
                q.setEndpoint(toolingBase + '/query?q=' + EncodingUtil.urlEncode(soql,'UTF-8'));
                q.setMethod('GET');
                q.setHeader('Authorization', 'Bearer ' + tokenResult.accessToken);

                HttpResponse qResp = new Http().send(q);
                if(qResp.getStatusCode() >= 300){
                    System.debug(LoggingLevel.ERROR,'FlowDeactivator query error for ' + apiName + ': ' + qResp.getBody());
                    continue;
                }

                Map<String,Object> parsed = (Map<String,Object>) JSON.deserializeUntyped(qResp.getBody());
                List<Object> recs = (List<Object>) parsed.get('records');
                if(recs.isEmpty()){
                    continue;
                }

                String flowId = (String) ((Map<String,Object>) recs[0]).get('ActiveVersionId');
                if(flowId == null){
                    continue;
                }

                HttpRequest req = new HttpRequest();
                req.setEndpoint(toolingBase + '/sobjects/Flow/' + flowId);
                req.setMethod('PATCH');
                req.setHeader('Content-Type', 'application/json');
                req.setHeader('Authorization', 'Bearer ' + tokenResult.accessToken);
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