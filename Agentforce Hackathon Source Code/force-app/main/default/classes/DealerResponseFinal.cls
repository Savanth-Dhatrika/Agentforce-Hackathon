@JsonAccess(serializable='always' deserializable='always')
global class DealerResponseFinal {
    @InvocableVariable
    global List<DealerResponse> responses;

    global DealerResponseFinal(List<DealerResponse> responses) {
        this.responses = responses;
    }
}