global class AccountWrapper {
    @AuraEnabled
    @InvocableVariable(required=false)
    global Id accountId;
    
    global AccountWrapper() {}
    
    global AccountWrapper(Id accountId) {
        this.accountId = accountId;
    }
}