public class flowResponse {
    @AuraEnabled
    public String dealerId;
    @AuraEnabled
    public String dealerName;
    @AuraEnabled
    public String assetId;
    @AuraEnabled
    public String assetName;
    @AuraEnabled
    public List<DealerTestDriveService.SlotDto> availableSlots;
}