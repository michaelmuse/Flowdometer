//Thanks to ProfessorFlow and UnofficialSF for this Open Source Component!
@IsTest
global class CalculateBusinessHoursDiffTest {
    @IsTest
    static void check_diffInMilliSeconds() {
        Profile sysAdminProfile = [
            SELECT Id, Name
            FROM Profile
            WHERE Name = 'System administrator'
            LIMIT 1
        ];
        User adminUser = [
            SELECT Id, Name
            FROM User
            WHERE ProfileId = :sysAdminProfile.Id AND IsActive = TRUE
            LIMIT 1
        ];
        BusinessHours businessHours = [
            SELECT Id
            FROM BusinessHours
            WHERE Name = 'Default'
            LIMIT 1
        ];
        System.runAs(adminUser) {
            List<CalculateBusinessHoursDiff.request> inputParams = new List<CalculateBusinessHoursDiff.request>();
            CalculateBusinessHoursDiff.request pf = new CalculateBusinessHoursDiff.request();
            pf.startDate = Datetime.now();
            pf.endDate = Datetime.now().addDays(1);
            pf.businessHoursId = businessHours.Id;
            inputParams.add(pf);

            Test.startTest();
            List<CalculateBusinessHoursDiff.response> response = CalculateBusinessHoursDiff.getMilliSecondDiff(
                inputParams
            );
            Integer actualValue = (response[0].diffResult / 1000).intValue();
            Test.stopTest();

            System.assertNotEquals(
                null,
                actualValue,
                'The actual value should not be null.'
            );
            System.assert(
                actualValue >= 0,
                'The actual value should be greater than or equal to 0.'
            );
        }
    }
}
