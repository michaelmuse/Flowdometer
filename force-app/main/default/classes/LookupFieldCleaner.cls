/**
 * Deletes the DYNAMIC (runtime-created, unmanaged) lookup fields that
 * correlate tracked records with Flow__c, so the package can be uninstalled
 * without "field is in use" leftovers. Both directions are covered:
 *   - forward fields on tracked objects pointing at Flow__c
 *     (e.g. Opportunity.Stage_Flow__c, Account.<custom>__c)
 *   - dynamic reverse fields ON Flow__c pointing at tracked objects
 *     (e.g. Flow__c.QA_Tracked__c)
 *
 * Discovery is DESCRIBE-based: Flow__c's child relationships enumerate every
 * lookup pointing at it, and Flow__c's own field map yields its reverse
 * lookups. The previous implementation queried Tooling CustomField with a
 * `ReferenceTo` filter, which the platform rejects (HTTP 400 INVALID_FIELD:
 * "No such column 'ReferenceTo' on entity 'CustomField'" - confirmed
 * 2026-06-10), so it silently deleted nothing.
 *
 * PACKAGED fields are excluded by namespace: in a subscriber org the
 * package's own fields carry the namespace prefix while runtime-created
 * fields do not. (In the namespace-less packaging org this guard is inert,
 * but the uninstall helper is a subscriber-facing feature.)
 */
public with sharing class LookupFieldCleaner implements Queueable, Database.AllowsCallouts {
    private static final String API_VERSION = 'v62.0';

    public void execute(QueueableContext qc){
        FlowdometerTokenService.TokenResult tokenResult = FlowdometerTokenService.getToken();
        if(!tokenResult.success){
            System.debug(LoggingLevel.ERROR, 'LookupFieldCleaner: token acquisition failed – ' + tokenResult.errorMessage);
            return;
        }

        String ns = resolveNamespace();
        String nsPrefix = String.isBlank(ns) ? null : (ns + '__');
        Schema.DescribeSObjectResult flowDescribe = Flow__c.SObjectType.getDescribe();

        // Object API name -> set of field DeveloperNames (no __c suffix) to delete.
        Map<String, Set<String>> fieldsByObject = new Map<String, Set<String>>();

        // Forward direction: every lookup in the org pointing at Flow__c.
        for(Schema.ChildRelationship cr : flowDescribe.getChildRelationships()){
            Schema.SObjectField fld = cr.getField();
            if(fld == null){
                continue;
            }
            Schema.DescribeFieldResult dfr = fld.getDescribe();
            if(!dfr.isCustom()){
                continue;
            }
            String fieldName = dfr.getName();
            if(nsPrefix != null && fieldName.startsWith(nsPrefix)){
                continue; // packaged field (e.g. Step__c.Flow__c) - never delete
            }
            addTarget(fieldsByObject, cr.getChildSObject().getDescribe().getName(), fieldName);
        }

        // Reverse direction: dynamic lookups ON Flow__c pointing at tracked objects.
        for(Schema.SObjectField fld : flowDescribe.fields.getMap().values()){
            Schema.DescribeFieldResult dfr = fld.getDescribe();
            if(dfr.getType() != Schema.DisplayType.REFERENCE || !dfr.isCustom()){
                continue;
            }
            String fieldName = dfr.getName();
            if(nsPrefix != null && fieldName.startsWith(nsPrefix)){
                continue; // packaged lookup (e.g. Flowdometer__Opportunity__c)
            }
            addTarget(fieldsByObject, flowDescribe.getName(), fieldName);
        }

        if(fieldsByObject.isEmpty()){
            return;
        }

        // Resolve Tooling CustomField Ids. CustomField.TableEnumOrId holds the
        // API name for standard objects but the entity DURABLE ID for custom
        // objects, so map custom-object API names to durable ids first.
        Map<String, String> tableKeyByObject = new Map<String, String>();
        List<String> customObjectNames = new List<String>();
        for(String objName : fieldsByObject.keySet()){
            if(objName.endsWith('__c')){
                customObjectNames.add(objName);
            } else {
                tableKeyByObject.put(objName, objName);
            }
        }
        if(!customObjectNames.isEmpty()){
            for(EntityDefinition ed : [
                SELECT DurableId, QualifiedApiName FROM EntityDefinition
                WHERE QualifiedApiName IN :customObjectNames
            ]){
                tableKeyByObject.put(ed.QualifiedApiName, ed.DurableId);
            }
        }

        // One Tooling query for all candidate developer names, then exact-match
        // each row against its expected object key to avoid same-name fields on
        // unrelated objects.
        Set<String> devNames = new Set<String>();
        Map<String, String> objectByTableKey = new Map<String, String>();
        for(String objName : fieldsByObject.keySet()){
            String tableKey = tableKeyByObject.get(objName);
            if(tableKey == null){
                continue;
            }
            objectByTableKey.put(tableKey, objName);
            for(String fieldName : fieldsByObject.get(objName)){
                devNames.add(fieldName.removeEnd('__c'));
            }
        }
        if(devNames.isEmpty()){
            return;
        }

        List<String> quoted = new List<String>();
        for(String dn : devNames){
            quoted.add('\'' + String.escapeSingleQuotes(dn) + '\'');
        }
        String toolingBase = URL.getOrgDomainUrl().toExternalForm()
            + '/services/data/' + API_VERSION + '/tooling';
        String soql = 'SELECT Id, DeveloperName, TableEnumOrId, NamespacePrefix FROM CustomField ' +
                      'WHERE DeveloperName IN (' + String.join(quoted, ',') + ')';

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
            Map<String,Object> row = (Map<String,Object>) rec;
            if(row.get('NamespacePrefix') != null){
                continue; // belongs to a (this or another) managed package
            }
            String tableKey = (String) row.get('TableEnumOrId');
            String objName = objectByTableKey.get(tableKey);
            if(objName == null){
                continue; // same-named field on an object we don't target
            }
            String devName = (String) row.get('DeveloperName');
            if(!fieldsByObject.get(objName).contains(devName + '__c')){
                continue;
            }

            String fieldId = (String) row.get('Id');
            HttpRequest del = new HttpRequest();
            del.setEndpoint(toolingBase + '/sobjects/CustomField/' + fieldId + '?forceDelete=true');
            del.setMethod('DELETE');
            del.setHeader('Authorization', 'Bearer ' + tokenResult.accessToken);
            HttpResponse dresp = new Http().send(del);
            if(dresp.getStatusCode() >= 300){
                System.debug(LoggingLevel.ERROR,'Error deleting field ' + objName + '.' + devName + '__c (' + fieldId + '): ' + dresp.getBody());
            }
        }
    }

    private static void addTarget(Map<String, Set<String>> fieldsByObject, String objName, String fieldName){
        Set<String> fields = fieldsByObject.get(objName);
        if(fields == null){
            fields = new Set<String>();
            fieldsByObject.put(objName, fields);
        }
        fields.add(fieldName);
    }

    private static String resolveNamespace(){
        String className = LookupFieldCleaner.class.getName();
        return className.contains('.') ? className.substringBefore('.') : '';
    }
}
