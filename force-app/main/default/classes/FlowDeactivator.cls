public with sharing class FlowDeactivator implements Queueable, Database.AllowsCallouts {
    private static final String API_VERSION = 'v65.0';

    private Set<String> apiNames;
    public FlowDeactivator(Set<String> apiNames){
        this.apiNames = apiNames;
    }

    public void execute(QueueableContext qc){
        FlowdometerTokenService.TokenResult tokenResult = FlowdometerTokenService.getToken();
        if(!tokenResult.success){
            System.debug(LoggingLevel.ERROR, 'FlowDeactivator: token acquisition failed – ' + tokenResult.errorMessage);
            return;
        }

        String toolingBase = URL.getOrgDomainUrl().toExternalForm()
            + '/services/data/' + API_VERSION + '/tooling';

        for(String apiName : apiNames){
            try{
                String soql = 'SELECT Id, ActiveVersionId FROM FlowDefinition WHERE DeveloperName = \'' + apiName + '\'';
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

                Map<String,Object> flowDef = (Map<String,Object>) recs[0];
                if(flowDef.get('ActiveVersionId') == null){
                    continue; // already inactive
                }
                String flowDefinitionId = (String) flowDef.get('Id');

                // Deactivate by PATCHing the FlowDefinition's Metadata with
                // activeVersionNumber = 0 - the inverse of the activation
                // mechanism, confirmed working via Tooling. PATCHing the Flow
                // version record with {"Status":"Obsolete"} is REJECTED by the
                // platform (HTTP 400 REQUIRED_FIELD_MISSING: "You must provide
                // a valid Metadata field for InteractionDefinitionVersion" -
                // confirmed 2026-06-10).
                HttpRequest req = new HttpRequest();
                req.setEndpoint(toolingBase + '/sobjects/FlowDefinition/' + flowDefinitionId);
                req.setMethod('PATCH');
                req.setHeader('Content-Type', 'application/json');
                req.setHeader('Authorization', 'Bearer ' + tokenResult.accessToken);
                req.setBody('{"Metadata":{"activeVersionNumber":0}}');

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
