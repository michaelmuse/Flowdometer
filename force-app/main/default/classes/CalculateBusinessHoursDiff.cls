//Thanks to ProfessorFlow and UnofficialSF for this Open Source Component!
global with sharing class CalculateBusinessHoursDiff {
    global class request {
        @InvocableVariable(Label='Business Hours Id' Required=true)
        global String businessHoursId;
        @InvocableVariable(Label='Start Date' Required=true)
        global Datetime startDate;
        @InvocableVariable(Label='End Date' Required=true)
        global Datetime endDate;
    }

    global class response {
        @InvocableVariable(Label='Result (in millisecond)')
        global Long diffResult;
        @InvocableVariable(Label='Result (in second)')
        global Long diffResultSec;
        @InvocableVariable(Label='Result (in minute)')
        global Long diffResultMin;
        @InvocableVariable(Label='Error Message')
        global String errorMessage;
    }
    @InvocableMethod(
        Label='Professor Flow | Calculate Business Hours Difference'
        Description='Returns the difference in milliseconds,second or minute between a start and end Datetime based on a specific set of business hours.'
    )
    global static List<response> getMilliSecondDiff(List<request> inputParams) {
        List<response> finalList = new List<response>();
        response resp = new response();
        
        try {
            // Validate input parameters
            if (inputParams == null || inputParams.isEmpty()) {
                resp.errorMessage = 'Input parameters cannot be null or empty';
                finalList.add(resp);
                return finalList;
            }
            
            for (request pf : inputParams) {
                resp = new response();
                
                // Validate request parameters
                if (String.isBlank(pf.businessHoursId)) {
                    resp.errorMessage = 'Business Hours ID cannot be null or empty';
                    finalList.add(resp);
                    continue;
                }
                
                if (pf.startDate == null) {
                    resp.errorMessage = 'Start Date cannot be null';
                    finalList.add(resp);
                    continue;
                }
                
                if (pf.endDate == null) {
                    resp.errorMessage = 'End Date cannot be null';
                    finalList.add(resp);
                    continue;
                }
                
                // Check if business hours ID is valid
                try {
                    Long diffInMinutes = BusinessHours.diff(
                    pf.businessHoursId,
                    pf.startDate,
                    pf.endDate
                );
                    
                resp.diffResult = diffInMinutes;
                resp.diffResultSec = diffInMinutes / 1000;
                resp.diffResultMin = diffInMinutes / 60000;
                    resp.errorMessage = '';
                } catch (Exception ex) {
                    resp.errorMessage = 'Error calculating business hours difference: ' + ex.getMessage();
                    System.debug(LoggingLevel.ERROR, 'Business hours calculation error: ' + ex.getMessage());
                }
                
                finalList.add(resp);
            }
        } catch (Exception ex) {
            resp.errorMessage = 'Unexpected error: ' + ex.getMessage();
            System.debug(LoggingLevel.ERROR, 'Unexpected error in getMilliSecondDiff: ' + ex.getMessage() + '\n' + ex.getStackTraceString());
            finalList.add(resp);
        }

        return finalList;
    }
}
