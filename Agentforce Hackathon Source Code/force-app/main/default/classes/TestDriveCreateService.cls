@JsonAccess(serializable='always' deserializable='always')
global class TestDriveCreateService {
    
    
    
    // Request wrapper for InvocableMethod (Flow/Agent calls pass a list)
    @JsonAccess(serializable='always' deserializable='always')
    public class Request {
        @InvocableVariable(required=true)
        public String ZipCode;
        @InvocableVariable(required=true)
        public String VehicleName;
        @InvocableVariable(required=true)
        public Date PreferredDate;
    }
    
    
    // NOTE: DTO classes were moved to top-level Apex classes (SlotDto, AssetSlots, DealerResponse)
    @JsonAccess(serializable='always' deserializable='always')
    Public class DealerResponse {
        @InvocableVariable
        Public String dealerId;
        
        @InvocableVariable
        Public String dealerName;
        
        @InvocableVariable
        Public String dealerAddress;
        
        @InvocableVariable
        Public List<AssetSlots> assets;
        
        Public DealerResponse(String dealerId, String dealerName, String dealerAddress, List<AssetSlots> assets) {
            this.dealerId = dealerId;
            this.dealerName = dealerName;
            this.dealerAddress = dealerAddress;
            this.assets = assets;
        }
    }
    
    @JsonAccess(serializable='always' deserializable='always')
    Public class DealerResponseFinal {
        @InvocableVariable
        Public List<DealerResponse> responses;
        
        Public DealerResponseFinal(List<DealerResponse> responses) {
            this.responses = responses;
        }
    }
    
    @JsonAccess(serializable='always' deserializable='always')
    public class AssetSlots {
        @InvocableVariable
        public String assetId;
        
        @InvocableVariable
        public String assetName;
        
        @InvocableVariable
        public List<SlotDto> availableSlots;
        
        Public AssetSlots(String assetId, String assetName, List<SlotDto> availableSlots) {
            this.assetId = assetId;
            this.assetName = assetName;
            this.availableSlots = availableSlots;
        }
    }
    @JsonAccess(serializable='always' deserializable='always')
    public class SlotDto {
        @InvocableVariable
        public String slotId;
        
        @InvocableVariable
        public String timeSlot;
        
        Public SlotDto(String slotId, String timeSlot) {
            this.slotId = slotId;
            this.timeSlot = timeSlot;
        }
            
    }
    // Keep these comments here so future readers know to update top-level DTOs, not inner classes.
    
    @InvocableMethod(label='Find Available Test Drive Slots for Booking' description='Given zip and model, returns dealers with available assets and slots')
    public static List<DealerResponseFinal> findAvailableTestDriveSlots(List<Request> requests) {
        
        // ---------- CONFIGURATION: reuse existing org API names ----------
        String ATS_OBJECT = 'Working_Hours__c';
        String ATS_ASSET_FIELD = 'Account__c';
        String ATS_TIME_SLOT_FIELD = 'Time_Slot__c';
        
        String TESTDRIVE_OBJECT = 'Test_Drive__c';
        String TESTDRIVE_ASSET_FIELD = 'Asset__c';
        String TESTDRIVETIME_SLOT_FIELD = 'PreferredTimeSlot__c';
        String TESTDRIVEDATE_SLOT_FIELD = 'Preferred_Date__c';
        List<DealerResponse> dealerResults = new List<DealerResponse>();
        List<DealerResponseFinal> finalDealerResults = new List<DealerResponseFinal>();
        
        //if (requests == null || requests.isEmpty()) return dealerResults;
        
        Request singleRequest = requests[0];
        String zip = (singleRequest.ZipCode != null) ? singleRequest.ZipCode.trim() : null;
        String model = (singleRequest.VehicleName != null) ? singleRequest.VehicleName.trim() : null;
        Date preferredDate = (singleRequest.PreferredDate != null) ? singleRequest.PreferredDate : null;
        //if (zip == null || model == null) return dealerResults;
        
        // 1) Dealers by postal code and Type='Dealer'
        List<Account> dealers = [
            SELECT Id, Name, BillingAddress, BillingPostalCode, Type
            FROM Account
            WHERE BillingPostalCode = :zip
            AND Type = 'Dealer'
            LIMIT 200
        ];
        //if (dealers.isEmpty()) return dealerResults;
        Map<Id, Account> dealerById = new Map<Id, Account>();
        for (Account a : dealers) dealerById.put(a.Id, a);
        Set<Id> dealerIds = dealerById.keySet();
        
        // 2) Assets for those dealers matching model
        List<Asset> assets = [
            SELECT Id, Name, AccountId, VehicleId,
            Vehicle.Name
            FROM Asset
            WHERE AccountId IN :dealerIds
            AND VehicleId != null
            AND Vehicle.Name = :model
            LIMIT 1000
        ];
        //if (assets.isEmpty()) return dealerResults;
        
        Set<Id> assetIds = new Set<Id>();
        for (Asset a : assets) assetIds.add(a.Id);
        
        // 3) Asset time slots
        String atsQuery = 'SELECT Id, ' + ATS_ASSET_FIELD + ', ' + ATS_TIME_SLOT_FIELD +
            ' FROM ' + ATS_OBJECT + ' WHERE ' + ATS_ASSET_FIELD + ' IN :dealerIds ORDER BY ' + ATS_TIME_SLOT_FIELD;
            System.debug(atsQuery);
        List<SObject> atsList = Database.query(atsQuery);
        Map<Id, List<SObject>> slotsByDealer = new Map<Id, List<SObject>>();
        for (SObject s : atsList) {
            Id aid = (Id)s.get(ATS_ASSET_FIELD);
            if (!slotsByDealer.containsKey(aid)) slotsByDealer.put(aid, new List<SObject>());
            slotsByDealer.get(aid).add(s);
        }
        
        // 4) Booked slots from Test_Drive__c
        String tdQuery = 'SELECT Id, ' + TESTDRIVE_ASSET_FIELD + ', ' + TESTDRIVEDATE_SLOT_FIELD + ', ' + TESTDRIVETIME_SLOT_FIELD +
            ' FROM ' + TESTDRIVE_OBJECT + ' WHERE ' + TESTDRIVE_ASSET_FIELD + ' IN :assetIds AND ' + TESTDRIVEDATE_SLOT_FIELD + ' = :preferredDate AND ' + TESTDRIVETIME_SLOT_FIELD + ' != null';
        List<SObject> tdList = Database.query(tdQuery);
        Map<Id, List<String>> bookedSlotIdsByAsset = new Map<Id, List<String>>();
        for (SObject td : tdList) {
            Object slotTimeVal = td.get(TESTDRIVETIME_SLOT_FIELD);
            Object slotDateVal = td.get(TESTDRIVEDATE_SLOT_FIELD);
            if(slotTimeVal != null && slotDateVal != null){
                Id assetId = (Id)td.get(TESTDRIVE_ASSET_FIELD);
                if (!bookedSlotIdsByAsset.containsKey(assetId)) bookedSlotIdsByAsset.put(assetId, new List<String>());
                bookedSlotIdsByAsset.get(assetId).add((String)slotTimeVal);
            }
            
        }
        
        // 5) Group assets by dealer and build DealerResponse
        Map<Id, List<Asset>> assetsByDealer = new Map<Id, List<Asset>>();
        for (Asset a : assets) {
            if (!assetsByDealer.containsKey(a.AccountId)) assetsByDealer.put(a.AccountId, new List<Asset>());
            assetsByDealer.get(a.AccountId).add(a);
        }
        
        for (Id dealerId : assetsByDealer.keySet()) {
            // explicitly instantiate top-level DTOs so Apex compiler resolves them correctly
            DealerResponse dr = new DealerResponse(String.valueOf(dealerId), dealerById.containsKey(dealerId) ? dealerById.get(dealerId).Name : null, String.valueOf(dealerById.containsKey(dealerId) ? dealerById.get(dealerId).BillingAddress : null), new List<AssetSlots>());
            
            for (Asset a : assetsByDealer.get(dealerId)) {
                // explicitly instantiate AssetSlots (top-level class)
                AssetSlots assetSlots = new AssetSlots(String.valueOf(a.Id), a.Name, new List<SlotDto>());
                
                List<SObject> slots = slotsByDealer.containsKey(a.AccountId) ? slotsByDealer.get(a.AccountId) : new List<SObject>();
                for (SObject s : slots) {
                    String slot = (String)s.get('Time_Slot__c');
                    if (bookedSlotIdsByAsset.containsKey(a.Id)){ 
                        if (bookedSlotIdsByAsset.get(a.Id).contains(slot)) 
                        continue;
                    }
                    // explicitly instantiate SlotDto (top-level class) and populate fields
                    SlotDto sd = new SlotDto(a.Id+slot, (s.get(ATS_TIME_SLOT_FIELD) != null) ? String.valueOf(s.get(ATS_TIME_SLOT_FIELD)) : null);
                    assetSlots.availableSlots.add(sd);
                }
                
                if (!assetSlots.availableSlots.isEmpty()) {
                    dr.assets.add(assetSlots);
                }
            }
            
            if (!dr.assets.isEmpty()) {
                dealerResults.add(dr);
                DealerResponseFinal finalResponse = New DealerResponseFinal(dealerResults);
                finalDealerResults.add(finalResponse);
            }
        }
        
        return finalDealerResults;
    }
    
}