public class TestDataFactory {
  public static List<History__c> createHistoryRecords(Integer numRecords) {
    List<History__c> historyRecords = new List<History__c>();
    for (Integer i = 0; i < numRecords; i++) {
      historyRecords.add(
        new History__c()
          // Populate required fields here
      );
    }
    return historyRecords;
  }

  public static List<CustomObject__c> createCustomObjects(Integer numRecords) {
    List<CustomObject__c> customObjects = new List<CustomObject__c>();
    for (Integer i = 0; i < numRecords; i++) {
      customObjects.add(
        new CustomObject__c()
          // Populate required fields here
      );
    }
    return customObjects;
  }
}
