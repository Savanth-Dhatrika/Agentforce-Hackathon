public class TwilioWhatsAppController {

    // Credentials are loaded from Custom Metadata (Twilio_Settings__mdt) at runtime.
    // Do NOT add hardcoded credentials here.

    // ─── Invocable Request / Response ─────────────────────────────────────────

    public class SendMessageRequest {
        @InvocableVariable(label='To Number' description='Recipient phone number in E.164 format (e.g. +919059449683)' required=true)
        public String toNumber;

        @InvocableVariable(label='Message Body' description='Text content of the WhatsApp message' required=true)
        public String messageBody;
    }

    public class SendMessageResponse {
        @InvocableVariable(label='Is Success' description='True if the message was sent successfully')
        public Boolean isSuccess;

        @InvocableVariable(label='Result Message' description='Success confirmation or error detail')
        public String resultMessage;

        @InvocableVariable(label='Message SID' description='Twilio message SID returned on success')
        public String messageSid;
    }

    // ─── Invocable Method ─────────────────────────────────────────────────────

    @InvocableMethod(
        label='Send WhatsApp Message'
        description='Sends a WhatsApp message via Twilio to the specified number using credentials stored in Twilio_Settings__mdt'
        category='WhatsApp'
    )
    public static List<SendMessageResponse> sendMessage(List<SendMessageRequest> requests) {
        List<SendMessageResponse> responses = new List<SendMessageResponse>();

        Twilio_Settings__mdt settings = loadSettings();

        for (SendMessageRequest input : requests) {
            SendMessageResponse resp = new SendMessageResponse();

            if (String.isBlank(input.messageBody)) {
                resp.isSuccess     = false;
                resp.resultMessage = 'Message body is required.';
                responses.add(resp);
                continue;
            }

            if (String.isBlank(input.toNumber)) {
                resp.isSuccess     = false;
                resp.resultMessage = 'Recipient phone number is required.';
                responses.add(resp);
                continue;
            }

            if (settings == null) {
                resp.isSuccess     = false;
                resp.resultMessage = 'Twilio configuration not found. Please set up Twilio_Settings__mdt.Default.';
                responses.add(resp);
                continue;
            }

            String accountSid = settings.Account_SID__c;
            String authToken  = settings.Auth_Token__c;
            String fromNumber = settings.From_Number__c;
            String normalised = input.toNumber.trim();
            String recipient  = normalised.startsWith('whatsapp:')
                                    ? normalised
                                    : normalised.startsWith('+')
                                        ? ('whatsapp:' + normalised)
                                        : ('whatsapp:+91' + normalised);

            String endpoint = 'https://api.twilio.com/2010-04-01/Accounts/'
                            + accountSid + '/Messages.json';

            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

            Blob credentials = Blob.valueOf(accountSid + ':' + authToken);
            req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(credentials));

            req.setBody(
                'From=' + EncodingUtil.urlEncode(fromNumber,        'UTF-8') +
                '&To='  + EncodingUtil.urlEncode(recipient,         'UTF-8') +
                '&Body='+ EncodingUtil.urlEncode(input.messageBody, 'UTF-8')
            );

            try {
                HttpResponse res = new Http().send(req);

                if (res.getStatusCode() == 201) {
                    Map<String, Object> responseJson =
                        (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    resp.messageSid    = (String) responseJson.get('sid');
                    resp.resultMessage = 'WhatsApp message sent successfully! SID: ' + resp.messageSid;
                    resp.isSuccess     = true;
                } else {
                    resp.resultMessage = 'Failed to send message. Status: '
                                       + res.getStatusCode() + ' — ' + res.getBody();
                    resp.isSuccess     = false;
                }

            } catch (Exception e) {
                resp.resultMessage = 'Error sending WhatsApp message: ' + e.getMessage();
                resp.isSuccess     = false;
            }

            responses.add(resp);
        }

        return responses;
    }

    // ─── Static Helper (for Apex-to-Apex calls) ───────────────────────────────

    @future(callout=true)
    public static void sendWhatsApp(String toPhone, String body) {
        SendMessageRequest request = new SendMessageRequest();
        request.toNumber    = toPhone;
        request.messageBody = body;
        List<SendMessageResponse> results = sendMessage(
            new List<SendMessageRequest>{ request }
        );
        system.debug('WhatsApp message send result: ' + (!results.isEmpty() && results[0].isSuccess == true));
    }

    // ─── Private Helpers ──────────────────────────────────────────────────────

    private static Twilio_Settings__mdt loadSettings() {
        List<Twilio_Settings__mdt> rows = [
            SELECT Account_SID__c, Auth_Token__c, From_Number__c
            FROM   Twilio_Settings__mdt
            WHERE  DeveloperName = 'Default'
            LIMIT  1
        ];
        return rows.isEmpty() ? null : rows[0];
    }
}