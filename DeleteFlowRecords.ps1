# Fetch all Flow__c IDs
sfdx force:data:soql:query --query "SELECT Id FROM Flowdometer__Flow__c" --result-format csv > Flow_ids_temp.csv

# Convert the encoding to UTF-8
Get-Content -Path "Flow_ids_temp.csv" -Encoding Unicode | Set-Content -Path "Flow_ids.csv" -Encoding utf8

# Delete temporary file
Remove-Item -Path "Flow_ids_temp.csv"

# Delete Flow__c records
sfdx force:data:bulk:delete -s Flowdometer__Flow__c -f Flow_ids.csv
