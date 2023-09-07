//Thanks to ProfessorFlow and UnofficialSF for this Open Source Component!
global class CalculateBusinessHoursDiff {
  global class request {
    @InvocableVariable(label='Business Hours Id' required=true)
    global String businessHoursId;
    @InvocableVariable(label='Start Date' required=true)
    global DateTime startDate;
    @InvocableVariable(label='End Date' required=true)
    global DateTime endDate;
  }

  global class response {
    @InvocableVariable(label='Result (in millisecond)')
    global long diffResult;
    @InvocableVariable(label='Result (in second)')
    global long diffResultSec;
    @InvocableVariable(label='Result (in minute)')
    global long diffResultMin;
  }
  @InvocableMethod(
    label='Professor Flow | Calculate Business Hours Difference'
    description='Returns the difference in milliseconds,second or minute between a start and end Datetime based on a specific set of business hours.'
  )
  global static List<response> getMilliSecondDiff(List<request> inputParams) {
    List<response> finalList = new List<response>();
    long diffinms = 0;
    //use utility method in businesshours
    if (inputParams != null && inputParams.size() > 0) {
      for (request pf : inputParams) {
        diffinms = BusinessHours.diff(
          pf.businessHoursId,
          pf.startDate,
          pf.endDate
        );
        response resp = new response();
        resp.diffResult = diffinms;
        resp.diffResultSec = diffinms / 1000;
        resp.diffResultMin = diffinms / 60000;
        finalList.add(resp);
      }
    }
    return finalList;
  }
}
