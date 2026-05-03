public with sharing class DealerTestDriveServiceGrouped {
    // ---------- CONFIGURATION: reuse existing org API names ----------
    private static final String ATS_OBJECT = 'Asset_Time_Slot__c';
    private static final String ATS_ASSET_FIELD = 'Asset__c';
    private static final String ATS_TIME_SLOT_FIELD = 'Time_Slot__c';

    private static final String TESTDRIVE_OBJECT = 'Test_Drive__c';
    private static final String TESTDRIVE_ASSET_FIELD = 'Asset__c';
    private static final String TESTDRIVE_SLOT_FIELD = 'Asset_Time_Slot__c';

    // Request wrapper for InvocableMethod (Flow/Agent calls pass a list)
    public class Request {
        @InvocableVariable(required=true)
        public String ZipCode;
        @InvocableVariable(required=true)
        public String ModelCode;
    }

    // NOTE: DTO classes were moved to top-level Apex classes (SlotDto, AssetSlots, DealerResponse)
    // Keep these comments here so future readers know to update top-level DTOs, not inner classes.

    @InvocableMethod(label='Find Available Test Drive Slots (Grouped by Dealer)' description='Given zip and model, returns dealers with available assets and slots')
    public static List<List<DealerResponse>> findAvailableTestDriveSlots(List<Request> requests) {
        List<DealerResponse> dealerResults = new List<DealerResponse>();
        //if (requests == null || requests.isEmpty()) return dealerResults;

        Request singleRequest = requests[0];
        String zip = (singleRequest.ZipCode != null) ? singleRequest.ZipCode.trim() : null;
        String model = (singleRequest.ModelCode != null) ? singleRequest.ModelCode.trim() : null;
        //if (zip == null || model == null) return dealerResults;

        // 1) Dealers by postal code and Type='Dealer'
        List<Account> dealers = [
            SELECT Id, Name, BillingPostalCode, Type
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
                   Vehicle.VehicleDefinition.ModelCode
            FROM Asset
            WHERE AccountId IN :dealerIds
              AND VehicleId != null
              AND Vehicle.VehicleDefinition.ModelCode = :model
            LIMIT 1000
        ];
        //if (assets.isEmpty()) return dealerResults;

        Set<Id> assetIds = new Set<Id>();
        for (Asset a : assets) assetIds.add(a.Id);

        // 3) Asset time slots
        String atsQuery = 'SELECT Id, ' + ATS_ASSET_FIELD + ', ' + ATS_TIME_SLOT_FIELD +
                          ' FROM ' + ATS_OBJECT + ' WHERE ' + ATS_ASSET_FIELD + ' IN :assetIds ORDER BY ' + ATS_TIME_SLOT_FIELD;
        List<SObject> atsList = Database.query(atsQuery);
        Map<Id, List<SObject>> slotsByAsset = new Map<Id, List<SObject>>();
        for (SObject s : atsList) {
            Id aid = (Id)s.get(ATS_ASSET_FIELD);
            if (!slotsByAsset.containsKey(aid)) slotsByAsset.put(aid, new List<SObject>());
            slotsByAsset.get(aid).add(s);
        }

        // 4) Booked slots from Test_Drive__c
        String tdQuery = 'SELECT Id, ' + TESTDRIVE_ASSET_FIELD + ', ' + TESTDRIVE_SLOT_FIELD +
                         ' FROM ' + TESTDRIVE_OBJECT + ' WHERE ' + TESTDRIVE_ASSET_FIELD + ' IN :assetIds AND ' + TESTDRIVE_SLOT_FIELD + ' != null';
        List<SObject> tdList = Database.query(tdQuery);
        Set<Id> bookedSlotIds = new Set<Id>();
        for (SObject td : tdList) {
            Object slotVal = td.get(TESTDRIVE_SLOT_FIELD);
            if (slotVal != null) bookedSlotIds.add((Id)slotVal);
        }

        // 5) Group assets by dealer and build DealerResponse
        Map<Id, List<Asset>> assetsByDealer = new Map<Id, List<Asset>>();
        for (Asset a : assets) {
            if (!assetsByDealer.containsKey(a.AccountId)) assetsByDealer.put(a.AccountId, new List<Asset>());
            assetsByDealer.get(a.AccountId).add(a);
        }

        for (Id dealerId : assetsByDealer.keySet()) {
            // explicitly instantiate top-level DTOs so Apex compiler resolves them correctly
            DealerResponse dr = new DealerResponse();
            dr.dealerId = String.valueOf(dealerId);
            dr.dealerName = dealerById.containsKey(dealerId) ? dealerById.get(dealerId).Name : null;
            dr.assets = new List<AssetSlots>();

            for (Asset a : assetsByDealer.get(dealerId)) {
                // explicitly instantiate AssetSlots (top-level class)
                AssetSlots assetSlots = new AssetSlots();
                assetSlots.assetId = String.valueOf(a.Id);
                assetSlots.assetName = a.Name;
                assetSlots.availableSlots = new List<SlotDto>();

                List<SObject> slots = slotsByAsset.containsKey(a.Id) ? slotsByAsset.get(a.Id) : new List<SObject>();
                for (SObject s : slots) {
                    Id slotId = (Id)s.get('Id');
                    if (bookedSlotIds.contains(slotId)) continue;
                    // explicitly instantiate SlotDto (top-level class) and populate fields
                    SlotDto sd = new SlotDto();
                    sd.slotId = String.valueOf(slotId);
                    Object tsVal = s.get(ATS_TIME_SLOT_FIELD);
                    sd.timeSlot = (tsVal != null) ? String.valueOf(tsVal) : null;
                    assetSlots.availableSlots.add(sd);
                }

                if (!assetSlots.availableSlots.isEmpty()) {
                    dr.assets.add(assetSlots);
                }
            }

            if (!dr.assets.isEmpty()) dealerResults.add(dr);
        }

        return New List<List<DealerResponse>>{dealerResults};
    }
}