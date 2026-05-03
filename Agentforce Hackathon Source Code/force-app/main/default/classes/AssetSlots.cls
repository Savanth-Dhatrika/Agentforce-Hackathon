public class AssetSlots {
    @InvocableVariable
    @AuraEnabled
    public String assetId;
    @InvocableVariable
    @AuraEnabled
    public String assetName;
    @InvocableVariable
    @AuraEnabled
    public List<SlotDto> availableSlots;
}