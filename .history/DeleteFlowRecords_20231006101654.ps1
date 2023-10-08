# Fetch all Flow__c IDs
sfdx force:data:soql:query --query "SELECT Id FROM Flowdometer__Flow__c" --result-format csv > Flow_ids.csv

# Delete Flow__c records
sfdx force:data:bulk:delete -s Flowdometer__Flow__c -f Flow_ids.csv
