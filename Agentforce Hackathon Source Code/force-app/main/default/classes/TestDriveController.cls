public with sharing class TestDriveController {
    
    @AuraEnabled
    public static String createTestDrive(String dealerId, String assetId, String slotTime, String slotDate) {
        Test_Drive__c record = new Test_Drive__c(
            Dealership__c = dealerId,
            Asset__c = assetId,
            PreferredTimeSlot__c = slotTime,
            Preferred_Date__c = Date.valueOf(slotDate)
        );
        
        insert record;
        return (String)record.Id;
    }
}