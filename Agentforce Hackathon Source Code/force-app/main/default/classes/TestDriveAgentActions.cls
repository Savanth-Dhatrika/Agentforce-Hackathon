/**
 * @description Invocable Actions for Agentforce Test Drive Agent
 * These actions are exposed to Agentforce for autonomous booking operations
 * @author Uni Cars Development Team
 */
public class TestDriveAgentActions {
    
    /**
     * @description Creates a test drive - Main action for Agentforce
     * @param requests List of booking requests from the agent
     * @return List of booking results
     */
    @InvocableMethod(
        label='Create Test Drive'
        description='Create a test drive for a customer at the nearest dealership based on their zip code'
        category='Test Drive'
    )
    public static List<BookingResponse> bookTestDrive(List<BookingRequest> requests) {
        List<BookingResponse> responses = new List<BookingResponse>();
        
        for (BookingRequest req : requests) {
            BookingResponse resp = new BookingResponse();
            
            try {
                // Validate required fields
                if (String.isBlank(req.customerName)) {
                    resp.isSuccess = false;
                    resp.responseMessage = 'I need your name to book the test drive. Could you please provide your full name?';
                    responses.add(resp);
                    continue;
                }
                
                if (String.isBlank(req.customerEmail) && String.isBlank(req.customerPhone)) {
                    resp.isSuccess = false;
                    resp.responseMessage = 'I need either your email or phone number to send the confirmation. Which would you prefer to share?';
                    responses.add(resp);
                    continue;
                }
                
                if (String.isBlank(req.assetId)) {
                    resp.isSuccess = false;
                    resp.responseMessage = 'Which Uni vehicle would you like to test drive? We have the Uni E1, Uni E3, and Uni EX SUV available.';
                    responses.add(resp);
                    continue;
                }
                
                if (String.isBlank(req.preferredDate)) {
                    resp.isSuccess = false;
                    resp.responseMessage = 'When would you like to come in for the test drive? Please share your preferred date.';
                    responses.add(resp);
                    continue;
                }
                
                if (String.isBlank(req.zipCode)) {
                    resp.isSuccess = false;
                    resp.responseMessage = 'To find the nearest dealership, I need your zip code. What\'s your zip code?';
                    responses.add(resp);
                    continue;
                }
                
                // Validate date is not in the past
                if (Date.valueOf(req.preferredDate) < Date.today()) {
                    resp.isSuccess = false;
                    resp.responseMessage = 'The date you selected is in the past. Please choose a date from today onwards.';
                    responses.add(resp);
                    continue;
                }
                
                // Default time slot if not provided
                String timeSlot = String.isBlank(req.preferredTime) ? '10:00 AM - 11:00 AM' : req.preferredTime;
                
                // Call the service to create the booking
                TestDriveBookingService.TestDriveBookingResult bookingResult = 
                    TestDriveBookingService.createTestDriveBooking(
                        req.customerName,
                        req.customerEmail,
                        req.customerPhone,
                        req.assetId,
                        req.dealershipAccountId,
                        Date.valueOf(req.preferredDate),
                        timeSlot,
                        req.zipCode
                    );
                
                resp.isSuccess = bookingResult.isSuccess;
                resp.testDriveId = bookingResult.testDriveId;
                resp.confirmationNumber = bookingResult.confirmationNumber;
                resp.dealershipName = bookingResult.dealershipName;
                resp.vehicleName = bookingResult.vehicleName;
                resp.scheduledDate = String.valueOf(bookingResult.scheduledDateTime);
                resp.timeSlot = bookingResult.timeSlot;
                
                if (bookingResult.isSuccess) {
                    resp.responseMessage = 'Excellent! Your test drive is confirmed!\n\n' +
                        '🚗 Vehicle: ' + bookingResult.vehicleName + '\n' +
                        '📍 Dealership: ' + bookingResult.dealershipName + '\n' +
                        '📅 Date: ' + bookingResult.scheduledDateTime + '\n' +
                        '⏰ Time: ' + bookingResult.timeSlot + '\n' +
                        '🎫 Confirmation #: ' + bookingResult.confirmationNumber + '\n\n' +
                        'You\'ll receive a confirmation message shortly. See you soon!';

                    // Send WhatsApp confirmation if customer phone is available
                    if (String.isNotBlank(req.customerPhone)) {
                        String whatsAppMessage =
                            'Hi ' + req.customerName + '! Your Uni Cars test drive is confirmed.\n\n' +
                            '🚗 Vehicle: ' + bookingResult.vehicleName + '\n' +
                            '📍 Dealership: ' + bookingResult.dealershipName + '\n' +
                            '📅 Date: ' + bookingResult.scheduledDateTime.format() + '\n' +
                            '⏰ Time: ' + bookingResult.timeSlot + '\n' +
                            '🎫 Confirmation #: ' + bookingResult.confirmationNumber + '\n\n' +
                            'See you soon! — Uni Cars Team';
                        TwilioWhatsAppController.sendWhatsApp(req.customerPhone, whatsAppMessage);
                    }
                } else {
                    resp.responseMessage = bookingResult.errorMessage;
                }
                
            } catch (Exception e) {
                resp.isSuccess = false;
                resp.responseMessage = 'I apologize, but I encountered an issue while booking. Please try again or contact our support team.';
            }
            
            responses.add(resp);
        }
        
        return responses;
    }
    
    /**
     * @description Request wrapper for test drive booking
     */
    @JsonAccess(serializable='always' deserializable='always')
    public class BookingRequest {
        @InvocableVariable(label='Customer Name' description='Full name of the customer')
        public String customerName;
        
        @InvocableVariable(label='Customer Email' description='Email address of the customer')
        public String customerEmail;
        
        @InvocableVariable(label='Customer Phone' description='Phone number of the customer')
        public String customerPhone;
        
        @InvocableVariable(label='Asset ID' description='ID of the asset for test drive')
        public String assetId;

        @InvocableVariable(label='Dealership Account Id' description='Id of the assigned dealership')
        public String dealershipAccountId;
        
        @InvocableVariable(label='Preferred Date' description='Preferred date for the test drive')
        public String preferredDate;
        
        @InvocableVariable(label='Preferred Time' description='Preferred time slot (e.g., 10:00 AM - 11:00 AM)')
        public String preferredTime;
        
        @InvocableVariable(label='Zip Code' description='Customer zip code for dealer routing')
        public String zipCode;
    }
    
    /**
     * @description Response wrapper for test drive booking
     */
    @JsonAccess(serializable='always' deserializable='always')
    public class BookingResponse {
        @InvocableVariable(label='Is Success' description='Whether the booking was successful')
        public Boolean isSuccess;
        
        @InvocableVariable(label='Response Message' description='Message to display to the customer')
        public String responseMessage;
        
        @InvocableVariable(label='Test Drive Id' description='ID of the created Test Drive record')
        public String testDriveId;
        
        @InvocableVariable(label='Confirmation Number' description='Unique confirmation number')
        public String confirmationNumber;
        
        @InvocableVariable(label='Dealership Name' description='Name of the assigned dealership')
        public String dealershipName;
        
        @InvocableVariable(label='Vehicle Name' description='Name of the vehicle model')
        public String vehicleName;
        
        @InvocableVariable(label='Scheduled Date' description='Confirmed date of the test drive')
        public String scheduledDate;
        
        @InvocableVariable(label='Time Slot' description='Confirmed time slot')
        public String timeSlot;
    }
}