/**
 * @description Service class for Test Drive booking operations
 * Uses Automotive Cloud OOTB objects: Lead, TestDrive, Vehicle, Account (Dealer)
 * @author Uni Cars Development Team
 */
public class TestDriveBookingService {
    
    /**
     * @description Creates a test drive booking with all required information
     * @param customerName Full name of the customer
     * @param customerEmail Customer email address
     * @param customerPhone Customer phone number
     * @param assetId ID of the vehicle asset
     * @param dealershipAccountId ID of the dealership account
     * @param preferredDate Preferred date for test drive
     * @param preferredTime Preferred time slot
     * @param zipCode Customer's zip code for dealer routing
     * @return TestDriveBookingResult containing booking details
     */
    public static TestDriveBookingResult createTestDriveBooking(
        String customerName,
        String customerEmail,
        String customerPhone,
        String assetId,
        String dealershipAccountId,
        Date preferredDate,
        String preferredTime,
        String zipCode
    ) {
        TestDriveBookingResult result = new TestDriveBookingResult();
        Savepoint sp = Database.setSavepoint();
        
        try {
            // Step 1: Find or create the Lead
            Lead customerLead = findOrCreateLead(customerName, customerEmail, customerPhone, zipCode);
            result.leadId = customerLead.Id;
            
            // Step 2: Find the Vehicle
            Vehicle vehicle = findVehicle(assetId);
            if (vehicle == null) {
                result.isSuccess = false;
                result.errorMessage = 'Vehicle model for asset ID "' + assetId + '" not found. Please select a valid model.';
                return result;
            }
            result.vehicleName = vehicle.Name;
            
            // Step 3: Find the nearest dealership based on zip code
            Account dealership = findDealership(dealershipAccountId);
            if (dealership == null) {
                result.isSuccess = false;
                result.errorMessage = 'No dealership found for the provided account ID. Please try a different location.';
                return result;
            }
            result.dealershipId = dealership.Id;
            result.dealershipName = dealership.Name;
            
            // Step 4: Create the Test Drive record (Automotive Cloud OOTB object)
            Test_Drive__c testDrive = createTestDriveRecord(
                customerLead.Id,
                vehicle.Name,
                dealership.Id,
                customerPhone,
                preferredDate,
                preferredTime,
                zipCode
            );
            result.testDriveId = testDrive.Id;
            result.confirmationNumber = generateConfirmationNumber(testDrive.Id);
            result.scheduledDateTime = preferredDate;
            result.timeSlot = preferredTime;
            
            // Step 5: Update Lead with dealership assignment
            customerLead.OwnerId = dealership.OwnerId;
            update customerLead;
            
            result.isSuccess = true;
            result.message = 'Your test drive has been booked successfully! Confirmation #' + result.confirmationNumber;
            
        } catch (Exception e) {
            Database.rollback(sp);
            result.isSuccess = false;
            result.errorMessage = 'An error occurred while booking your test drive: ' + e.getMessage();
        }
        
        return result;
    }
    
    /**
     * @description Finds existing lead or creates a new one
     */
    private static Lead findOrCreateLead(String name, String email, String phone, String zipCode) {
        List<Lead> existingLeads = [
            SELECT Id, Name, Email, Phone, PostalCode, OwnerId
            FROM Lead
            WHERE Email = :email
            LIMIT 1
        ];
        
        if (!existingLeads.isEmpty()) {
            Lead existingLead = existingLeads[0];
            existingLead.Phone = phone;
            existingLead.PostalCode = zipCode;
            update existingLead;
            return existingLead;
        }
        
        // Parse name into first and last
        String firstName = '';
        String lastName = name;
        if (name.contains(' ')) {
            Integer spaceIndex = name.indexOf(' ');
            firstName = name.substring(0, spaceIndex);
            lastName = name.substring(spaceIndex + 1);
        }
        
        Lead newLead = new Lead(
            FirstName = firstName,
            LastName = lastName,
            Email = email,
            Phone = phone,
            PostalCode = zipCode,
            LeadSource = 'Agentforce - Test Drive',
            Company = 'Individual',
            Status = 'New'
        );
        insert newLead;
        return newLead;
    }
    
    /**
     * @description Finds a vehicle by asset ID
     */
    private static Vehicle findVehicle(String assetId) {
        Asset asset = [SELECT Id, Name, VehicleId FROM Asset WHERE Id = :assetId LIMIT 1];
        
        List<Vehicle> vehicles = [
            SELECT Id, Name, ModelName
            FROM Vehicle
            WHERE Id = :asset.VehicleId
            ORDER BY Name
            LIMIT 1
        ];
        return vehicles.isEmpty() ? null : vehicles[0];
    }
    
    /**
     * @description Finds the nearest dealership based on zip code
     * Uses Account object with RecordType = Dealer
     */
    private static Account findDealership(String dealerAccountId) {
        
        List<Account> dealerships = [
            SELECT Id, Name, OwnerId, BillingPostalCode, BillingCity, BillingState, Phone
            FROM Account
            WHERE Id = :dealerAccountId
            LIMIT 1
        ];
        
        return dealerships.isEmpty() ? null : dealerships[0];
    }
    
    /**
     * @description Creates the Test Drive record using Automotive Cloud OOTB object
     */
    private static Test_Drive__c createTestDriveRecord(
        Id leadId,
        String vehicleModel,
        Id dealershipId,
        String customerPhone,
        Date preferredDate,
        String preferredTime,
        String zipCode
    ) {
        Test_Drive__c td = new Test_Drive__c(
            Customer__c = leadId,
            Model_Interested__c = vehicleModel,
            Dealership__c = dealershipId,
            Mobile_Number__c = customerPhone,
            Preferred_Date__c = preferredDate,
            Test_Drive_Date_Time__c = DateTime.newInstance(preferredDate, Time.newInstance(0, 0, 0, 0)),
            PreferredTimeSlot__c = preferredTime,
            CustomerZipCode__c = zipCode,
            Status__c = 'Scheduled',
            BookingChannel__c = 'Agentforce'
        );
        insert td;
        return td;
    }
    
    /**
     * @description Generates a unique confirmation number
     */
    private static String generateConfirmationNumber(Id testDriveId) {
        return 'EC-' + String.valueOf(testDriveId).right(8).toUpperCase();
    }
    
    /**
     * @description Gets available time slots for a given date
     */
    public static List<String> getAvailableTimeSlots(Date requestedDate, Id dealershipId) {
        List<String> allSlots = new List<String>{
            '09:00 AM - 10:00 AM',
            '10:00 AM - 11:00 AM',
            '11:00 AM - 12:00 PM',
            '01:00 PM - 02:00 PM',
            '02:00 PM - 03:00 PM',
            '03:00 PM - 04:00 PM',
            '04:00 PM - 05:00 PM'
        };
        
        // Get booked slots for the date
        Set<String> bookedSlots = new Set<String>();
        for (Test_Drive__c td : [
            SELECT PreferredTimeSlot__c
            FROM Test_Drive__c
            WHERE DAY_ONLY(Test_Drive_Date_Time__c) = :requestedDate
            AND Dealership__c = :dealershipId
            AND Status__c != 'Cancelled'
        ]) {
            if (td.PreferredTimeSlot__c != null) {
                bookedSlots.add(td.PreferredTimeSlot__c);
            }
        }
        
        // Filter available slots
        List<String> availableSlots = new List<String>();
        for (String slot : allSlots) {
            if (!bookedSlots.contains(slot)) {
                availableSlots.add(slot);
            }
        }
        
        return availableSlots;
    }
    
    /**
     * @description Gets all available vehicle models
     */
    public static List<VehicleModelInfo> getAvailableVehicleModels() {
        List<VehicleModelInfo> models = new List<VehicleModelInfo>();
        
        for (VehicleDefinition vd : [
            SELECT Id, Name, ModelCode, VariantName, BodyType, FuelSource,
                   MaximumBatteryRange, BasePrice__c
            FROM VehicleDefinition
            ORDER BY Name
        ]) {
            models.add(new VehicleModelInfo(vd));
        }
        
        return models;
    }
    
    /**
     * @description Inner class for vehicle model information
     */
    public class VehicleModelInfo {
        @AuraEnabled public Id vehicleId { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String modelCode { get; set; }
        @AuraEnabled public String variantName { get; set; }
        @AuraEnabled public String bodyType { get; set; }
        @AuraEnabled public String fuelSource { get; set; }
        @AuraEnabled public String maximumBatteryRange { get; set; }
        @AuraEnabled public Decimal basePrice { get; set; }
        
        public VehicleModelInfo(VehicleDefinition vd) {
            this.vehicleId = vd.Id;
            this.name = vd.Name;
            this.modelCode = vd.ModelCode;
            this.variantName = vd.VariantName;
            this.bodyType = vd.BodyType;
            this.fuelSource = vd.FuelSource;
            this.maximumBatteryRange = vd.MaximumBatteryRange;
            this.basePrice = vd.BasePrice__c;
        }
    }
    
    /**
     * @description Result wrapper for test drive booking
     */
    public class TestDriveBookingResult {
        @AuraEnabled public Boolean isSuccess { get; set; }
        @AuraEnabled public String message { get; set; }
        @AuraEnabled public String errorMessage { get; set; }
        @AuraEnabled public Id testDriveId { get; set; }
        @AuraEnabled public Id leadId { get; set; }
        @AuraEnabled public Id dealershipId { get; set; }
        @AuraEnabled public String dealershipName { get; set; }
        @AuraEnabled public String vehicleName { get; set; }
        @AuraEnabled public String confirmationNumber { get; set; }
        @AuraEnabled public Date scheduledDateTime { get; set; }
        @AuraEnabled public String timeSlot { get; set; }
        
        public TestDriveBookingResult() {
            this.isSuccess = false;
        }
    }
}