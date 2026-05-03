@JsonAccess(serializable='always' deserializable='always')
global class DealerResponse {
    @InvocableVariable
    @AuraEnabled
    global String dealerId;
    @InvocableVariable
    @AuraEnabled
    global String dealerName;
    @InvocableVariable
    @AuraEnabled
    global List<AssetSlots> assets;
}