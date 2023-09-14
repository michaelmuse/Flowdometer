//Thanks to ProfessorFlow and UnofficialSF for this Open Source Component!
@isTest
global class CalculateBusinessHoursDiffTest {
  @isTest
  static void check_diffInMilliSeconds() {
    Profile sysadminprofile = [
      SELECT Id, name
      FROM profile
      WHERE Name = 'System administrator'
      LIMIT 1
    ];
    User adminUser = [
      SELECT Id, Name
      FROM user
      WHERE profileId = :sysadminprofile.Id AND isactive = TRUE
      LIMIT 1
    ];
    BusinessHours bhoursId = [
      SELECT Id
      FROM BusinessHours
      WHERE Name = 'Default'
      LIMIT 1
    ];
    System.runAs(adminUser) {
      List<CalculateBusinessHoursDiff.request> inputparams = new List<CalculateBusinessHoursDiff.request>();
      CalculateBusinessHoursDiff.request pf = new CalculateBusinessHoursDiff.request();
      pf.startDate = Datetime.now();
      pf.endDate = Datetime.now().addDays(1);
      pf.businessHoursId = bhoursId.Id;
      inputparams.add(pf);
      Test.startTest();
      List<CalculateBusinessHoursDiff.response> response = CalculateBusinessHoursDiff.getMilliSecondDiff(inputparams);
      Integer actualValue = (response[0].diffResult / 1000).intValue();
      Test.stopTest();
      System.assertNotEquals(null, actualValue, 'The actual value should not be null.');
      System.assert(actualValue >= 0, 'The actual value should be greater than or equal to 0.');
    }
  }
}