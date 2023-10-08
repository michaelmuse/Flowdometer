# Fetch all Listener__c IDs
sfdx force:data:soql:query --query "SELECT Id FROM Flowdometer__Listener__c" --result-format csv > Listener_ids.csv

# Delete Listener__c records
sfdx force:data:bulk:delete -s Flowdometer__Listener__c -f Listener_ids.csv
