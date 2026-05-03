@JsonAccess(serializable='always' deserializable='always')
global class Request {
        @InvocableVariable(required=true)
        global String ZipCode;
        @InvocableVariable(required=true)
        global String ModelCode;
    }