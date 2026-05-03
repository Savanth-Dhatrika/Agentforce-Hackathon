public with sharing class DealerTestDriveService {
    // ---------- CONFIGURATION: exact API names discovered in the org ----------
    private static final String ATS_OBJECT = 'Asset_Time_Slot__c';
    private static final String ATS_ASSET_FIELD = 'Asset__c';
    private static final String ATS_TIME_SLOT_FIELD = 'Time_Slot__c';

    // Asset -> Vehicle lookup field (confirmed VehicleId on Asset)
    // Vehicle -> VehicleDefinition field (VehicleDefinitionId)
    // VehicleDefinition fields (ModelCode exists in this org)
    // Test_Drive__c exact fields discovered:
    private static final String TESTDRIVE_OBJECT = 'Test_Drive__c';
    private static final String TESTDRIVE_ASSET_FIELD = 'Asset__c';
    private static final String TESTDRIVE_SLOT_FIELD = 'Asset_Time_Slot__c'; // lookup to Asset_Time_Slot__c
    private static final String TESTDRIVE_SLOT_RELATION = 'Asset_Time_Slot__r';
    private static final String TESTDRIVE_TESTDRIVE_DATETIME = 'Test_Drive_Date_Time__c';
    private static final String TESTDRIVE_CUSTOMER_ZIP = 'CustomerZipCode__c';
    private static final String TESTDRIVE_STATUS = 'Status__c';
    private static final String TESTDRIVE_DEALERSHIP = 'Dealership__c';
    private static final String TESTDRIVE_ASSET_FIELD_REL = 'Asset__r';

    // ---------------------------------------------------------------------------------------

    // Request wrapper for InvocableMethod (Flow/Agent calls pass a list)
    public class Request {
        @InvocableVariable(required=true)
        public String ZipCode;
        @InvocableVariable(required=true)
        public String ModelCode;
    }

    // Slot DTO
    public class SlotDto {
        @InvocableVariable
        public String slotId;
        @InvocableVariable
        public String timeSlot;
    }

    // Response wrapper
    
    public class Response {
        @InvocableVariable
        public String dealerId;
        @InvocableVariable
        public String dealerName;
        @InvocableVariable
        public String assetId;
        @InvocableVariable
        public String assetName;
        @InvocableVariable
        public List<SlotDto> availableSlots;
    }

    

    @InvocableMethod(label='Find Available Test Drive Slots' description='Given zip and model, returns available slots per dealer asset (processes one request at a time)')
    public static List<Response> findAvailableTestDriveSlots(List<Request> requests) {
        // The agent will provide a single request at a time. Process only the first request to match that pattern.
        List<Response> results = new List<Response>();
        if (requests == null || requests.isEmpty()) {
            return results;
        }

        Request singleRequest = requests[0];

        // Extract single zip and model code
        String zip = (singleRequest.ZipCode != null) ? singleRequest.ZipCode.trim() : null;
        String model = (singleRequest.ModelCode != null) ? singleRequest.ModelCode.trim() : null;
        if (zip == null || model == null) {
            return results;
        }

        // 1) Find dealer Accounts by postal code and Type = 'Dealer'
        List<Account> dealers = [
            SELECT Id, Name, BillingPostalCode, Type
            FROM Account
            WHERE BillingPostalCode = :zip
              AND Type = 'Dealer'
            LIMIT 200
        ];
        if (dealers.isEmpty()) return results;

        Map<Id, Account> dealerById = new Map<Id, Account>();
        for (Account a : dealers) dealerById.put(a.Id, a);
        Set<Id> dealerIds = dealerById.keySet();

        // 2) Find Assets at these dealers filtered by Vehicle model.
        // Traversal: Asset.VehicleId -> Vehicle -> Vehicle.VehicleDefinition.ModelCode
        List<Asset> assets = [
            SELECT Id, Name, AccountId, VehicleId,
                   Vehicle.Id, Vehicle.Name,
                   Vehicle.VehicleDefinition.Id, Vehicle.VehicleDefinition.ModelCode, Vehicle.VehicleDefinition.Name
            FROM Asset
            WHERE AccountId IN :dealerIds
              AND VehicleId != null
              AND Vehicle.VehicleDefinition.ModelCode = :model
            LIMIT 1000
        ];
        if (assets.isEmpty()) return results;

        Set<Id> assetIds = new Set<Id>();
        for (Asset a : assets) assetIds.add(a.Id);

        // 3) Query Asset_Time_Slot__c for these assets
        String atsQuery = 'SELECT Id, ' + ATS_ASSET_FIELD + ', ' + ATS_TIME_SLOT_FIELD +
                          ' FROM ' + ATS_OBJECT + ' WHERE ' + ATS_ASSET_FIELD + ' IN :assetIds ORDER BY ' + ATS_TIME_SLOT_FIELD;
        List<SObject> atsList = Database.query(atsQuery);

        // Group slots by Asset
        Map<Id, List<SObject>> slotsByAsset = new Map<Id, List<SObject>>();
        for (SObject s : atsList) {
            Id aid = (Id)s.get(ATS_ASSET_FIELD);
            if (!slotsByAsset.containsKey(aid)) slotsByAsset.put(aid, new List<SObject>());
            slotsByAsset.get(aid).add(s);
        }

        // 4) Query Test_Drive__c to find booked slot ids for these assets (assuming lookup to Asset_Time_Slot__c)
        String tdQuery = 'SELECT Id, ' + TESTDRIVE_ASSET_FIELD + ', ' + TESTDRIVE_SLOT_FIELD +
                         ' FROM ' + TESTDRIVE_OBJECT + ' WHERE ' + TESTDRIVE_ASSET_FIELD + ' IN :assetIds AND ' + TESTDRIVE_SLOT_FIELD + ' != null';
        List<SObject> tdList = Database.query(tdQuery);

        Set<Id> bookedSlotIds = new Set<Id>();
        for (SObject td : tdList) {
            Object slotVal = td.get(TESTDRIVE_SLOT_FIELD);
            if (slotVal != null) {
                bookedSlotIds.add((Id)slotVal);
            }
        }

        // 5) Assemble results: for each asset, include slots not booked
        Map<Id, String> dealerNameById = new Map<Id, String>();
        for (Account acc : dealers) dealerNameById.put(acc.Id, acc.Name);

        for (Asset a : assets) {
            Response resp = new Response();
            resp.dealerId = a.AccountId;
            resp.dealerName = dealerNameById.containsKey(a.AccountId) ? dealerNameById.get(a.AccountId) : null;
            resp.assetId = a.Id;
            resp.assetName = a.Name;
            resp.availableSlots = new List<SlotDto>();

            List<SObject> slots = slotsByAsset.containsKey(a.Id) ? slotsByAsset.get(a.Id) : new List<SObject>();
            for (SObject s : slots) {
                Id slotId = (Id)s.get('Id');
                if (bookedSlotIds.contains(slotId)) continue;
                SlotDto sd = new SlotDto();
                sd.slotId = slotId;
                sd.timeSlot = (String)s.get(ATS_TIME_SLOT_FIELD);
                resp.availableSlots.add(sd);
            }

            // include only if there are available slots
            if (!resp.availableSlots.isEmpty()) {
                results.add(resp);
            }
        }

        return results;
    }
}