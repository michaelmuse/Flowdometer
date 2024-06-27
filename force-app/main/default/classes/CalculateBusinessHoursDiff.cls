//Thanks to ProfessorFlow and UnofficialSF for this Open Source Component!
global class CalculateBusinessHoursDiff {
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
    }
    @InvocableMethod(
        Label='Professor Flow | Calculate Business Hours Difference'
        Description='Returns the difference in milliseconds,second or minute between a start and end Datetime based on a specific set of business hours.'
    )
    global static List<response> getMilliSecondDiff(List<request> inputParams) {
        List<response> finalList = new List<response>();
        Long diffInMinutes = 0;
        //use utility method in business hours
        if (inputParams != null && inputParams.size() > 0) {
            for (request pf : inputParams) {
                diffInMinutes = BusinessHours.diff(
                    pf.businessHoursId,
                    pf.startDate,
                    pf.endDate
                );
                response resp = new response();
                resp.diffResult = diffInMinutes;
                resp.diffResultSec = diffInMinutes / 1000;
                resp.diffResultMin = diffInMinutes / 60000;
                finalList.add(resp);
            }
        }

        return finalList;
    }
}
