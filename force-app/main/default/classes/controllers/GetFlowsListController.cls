public class GetFlowsListController {
    public GetFlowsListController(ApexPages.StandardController stdController) {
        String currentId = ApexPages.CurrentPage().getparameters().get('id');
        List<Flowdometer__Flow__c> flowList = [
            SELECT Id, Name, Flowdometer__Tracked_Field_Name__c
            FROM Flowdometer__Flow__c
            WHERE Flowdometer__Tracked_Object_ID__c = :currentId
        ];
    }
}
